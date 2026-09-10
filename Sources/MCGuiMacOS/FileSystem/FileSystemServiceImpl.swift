import Foundation
import MCGuiCore

/// Typed filesystem errors, mapped from the underlying `CocoaError`/`POSIXError` codes
/// `FileSystemServiceImpl` can encounter, per design.md's Error Handling Strategy.
public enum FileSystemServiceError: Error, Equatable {
    /// Directory read permission denied (`CocoaError` code 257).
    case permissionDenied(URL)
    /// `createDirectory` target already exists.
    case alreadyExists(URL)
    /// File in use by another process (`POSIXError.EBUSY`).
    case fileInUse(URL)
    /// Not enough free space at the destination (`POSIXError.ENOSPC`).
    case insufficientDiskSpace
    /// The volume was disconnected mid-operation (`POSIXError.ENOTCONN`).
    case volumeDisconnected(URL)
    /// A planned destination path exceeds the filesystem's maximum path length
    /// (`PATH_MAX`), per spec.md's Edge Case 7.
    case pathTooLong(URL)
}

/// macOS `FileSystemService` implementation backed by `FileManager`.
public final class FileSystemServiceImpl {
    private let fileManager: FileManager
    private let copyItem: (URL, URL) throws -> Void
    private let moveItem: (URL, URL) throws -> Void
    private let availableFreeSpace: (URL) throws -> Int64
    private let isSameVolume: (URL, URL) -> Bool

    /// - Parameters:
    ///   - copyItem, moveItem, availableFreeSpace, isSameVolume: Injectable seams over
    ///     the underlying filesystem primitives, defaulting to real `FileManager`/`URL`
    ///     calls. Tests use these to simulate `EBUSY` retries, `ENOSPC` failures, and
    ///     same-volume vs. cross-volume moves without needing multiple real volumes.
    public init(
        fileManager: FileManager = .default,
        copyItem: ((URL, URL) throws -> Void)? = nil,
        moveItem: ((URL, URL) throws -> Void)? = nil,
        availableFreeSpace: ((URL) throws -> Int64)? = nil,
        isSameVolume: ((URL, URL) -> Bool)? = nil
    ) {
        self.fileManager = fileManager
        self.copyItem = copyItem ?? { src, dst in try fileManager.copyItem(at: src, to: dst) }
        self.moveItem = moveItem ?? { src, dst in try fileManager.moveItem(at: src, to: dst) }
        self.availableFreeSpace = availableFreeSpace ?? { url in
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(values.volumeAvailableCapacity ?? 0)
        }
        self.isSameVolume = isSameVolume ?? { a, b in
            let volumeA = try? a.resourceValues(forKeys: [.volumeURLKey]).volume
            let volumeB = try? b.resourceValues(forKeys: [.volumeURLKey]).volume
            return volumeA == volumeB
        }
    }

    // MARK: - listDirectory

    // SPEC_DEVIATION (Fix 6, validation.md, Edge Case 4): spec.md asks for 10,000+-entry
    // directories to load incrementally (pagination/virtualization); this still returns
    // the full listing in one call. Real incremental loading needs an async/paginated
    // `FileSystemService.listDirectory` signature (an `AsyncSequence` or a cursor-based
    // page API) plus matching `PanelViewModel` state to accumulate pages as they arrive -
    // a protocol-level change out of this fix pass's budget (Fix 1/3's `onProgress`
    // pattern doesn't apply directly here: listing has no natural per-item side effect to
    // hang a callback off before the array is built). Deliberately deferred rather than a
    // half-measure (e.g. switching to `FileManager.enumerator` without any caller-facing
    // change to consume it incrementally would fix nothing observable). `List` itself
    // still renders lazily once the array is loaded, so the UI doesn't build 10,000 rows
    // eagerly - only the initial fetch blocks on the full directory read.
    public func listDirectory(_ url: URL) async throws -> [FileEntry] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .isHiddenKey
        ]

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [])
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            throw FileSystemServiceError.permissionDenied(url)
        }

        return contents.map { buildEntry(for: $0, keys: Set(keys)) }
    }

    private func buildEntry(for url: URL, keys: Set<URLResourceKey>) -> FileEntry {
        let values = try? url.resourceValues(forKeys: keys)
        let isDirectory = values?.isDirectory ?? false
        let isSymlink = values?.isSymbolicLink ?? false
        let size = Int64(values?.fileSize ?? 0)
        let creationDate = values?.creationDate ?? Date(timeIntervalSince1970: 0)
        let modificationDate = values?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
        let isHidden = values?.isHidden ?? false

        var symlinkTarget: URL?
        if isSymlink, let destination = try? fileManager.destinationOfSymbolicLink(atPath: url.path) {
            symlinkTarget = URL(fileURLWithPath: destination, relativeTo: url.deletingLastPathComponent())
        }

        let type: FileType = isSymlink ? .symlink : (isDirectory ? .directory : .file)
        let attributes = (try? fileManager.attributesOfItem(atPath: url.path)) ?? [:]
        let permissions = Self.permissions(fromPosix: (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0)

        return FileEntry(
            name: url.lastPathComponent,
            path: url,
            size: size,
            creationDate: creationDate,
            modificationDate: modificationDate,
            permissions: permissions,
            type: type,
            isHidden: isHidden,
            isSymlink: isSymlink,
            symlinkTarget: symlinkTarget
        )
    }

    private static func permissions(fromPosix mode: Int) -> FilePermissions {
        var result: FilePermissions = []
        if mode & 0o400 != 0 { result.insert(.ownerRead) }
        if mode & 0o200 != 0 { result.insert(.ownerWrite) }
        if mode & 0o100 != 0 { result.insert(.ownerExecute) }
        if mode & 0o040 != 0 { result.insert(.groupRead) }
        if mode & 0o020 != 0 { result.insert(.groupWrite) }
        if mode & 0o010 != 0 { result.insert(.groupExecute) }
        if mode & 0o004 != 0 { result.insert(.otherRead) }
        if mode & 0o002 != 0 { result.insert(.otherWrite) }
        if mode & 0o001 != 0 { result.insert(.otherExecute) }
        return result
    }

    // MARK: - createDirectory

    public func createDirectory(_ url: URL) async throws {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        } catch let error as CocoaError where error.code == .fileWriteFileExists {
            throw FileSystemServiceError.alreadyExists(url)
        }
    }

    // MARK: - copy

    /// Copies `plan.sources` into `plan.destinationDirectory`, reporting no progress.
    public func copy(_ plan: CopyMovePlan) async throws -> OperationResult {
        try await copy(plan, onProgress: { _ in })
    }

    /// Copies `plan.sources` into `plan.destinationDirectory`, calling `onProgress` once
    /// per source processed (FO-14) and checking for cancellation between sources
    /// (FO-16) - cancelling the calling `Task` throws `CancellationError` at the next
    /// source boundary, leaving already-copied files in place (matches the spec's "stops"
    /// behavior; it does not roll back completed files).
    ///
    /// Conflict handling (FO-06/FO-07): with `updateOnly == false` an existing
    /// destination entry is always overwritten; with `updateOnly == true` it is
    /// overwritten only when the source is newer, otherwise skipped. Renaming
    /// (FO-08) and cancelling (FO-09) are resolved upstream, before the plan reaches
    /// this method - `plan.sources`/`destinationDirectory` already reflect that choice.
    public func copy(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult {
        try ensureSufficientSpace(for: plan)
        try ensureValidPathLengths(for: plan)

        var failedItems: [FailedItem] = []
        var processedCount = 0
        let progress = OperationProgressTracker(sources: plan.sources)

        for source in plan.sources {
            try Task.checkCancellation()
            let destination = plan.destinationDirectory.appendingPathComponent(plan.renames[source.id] ?? source.name)
            do {
                if try resolveExistingDestination(source: source, destination: destination, options: plan.options) == .skip {
                    processedCount += 1
                    onProgress(progress.recordProcessed(source))
                    continue
                }

                try await copySingleFile(source, to: destination, options: plan.options)
                processedCount += 1
                onProgress(progress.recordProcessed(source))
            } catch {
                failedItems.append(try failedItemOrRethrowIfDisconnected(error, source: source))
            }
        }

        return OperationResult(
            success: failedItems.isEmpty,
            errorMessage: failedItems.isEmpty ? nil : "Some items failed to copy",
            processedCount: processedCount,
            failedItems: failedItems
        )
    }

    // MARK: - move

    /// Moves `plan.sources` into `plan.destinationDirectory`, reporting no progress.
    public func move(_ plan: CopyMovePlan) async throws -> OperationResult {
        try await move(plan, onProgress: { _ in })
    }

    /// Moves `plan.sources` into `plan.destinationDirectory`: renames within the same
    /// volume, copies then deletes the original across volumes (FO-04). Reports progress
    /// and checks cancellation the same way `copy(_:onProgress:)` does (FO-14, FO-16).
    public func move(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult {
        try ensureSufficientSpace(for: plan)
        try ensureValidPathLengths(for: plan)

        var failedItems: [FailedItem] = []
        var processedCount = 0
        let progress = OperationProgressTracker(sources: plan.sources)

        for source in plan.sources {
            try Task.checkCancellation()
            let destination = plan.destinationDirectory.appendingPathComponent(plan.renames[source.id] ?? source.name)
            do {
                if try resolveExistingDestination(source: source, destination: destination, options: plan.options) == .skip {
                    processedCount += 1
                    onProgress(progress.recordProcessed(source))
                    continue
                }

                if isSameVolume(source.path, plan.destinationDirectory) {
                    try await withEBUSYRetry(url: source.path) {
                        try moveItem(source.path, destination)
                    }
                } else {
                    try await copySingleFile(source, to: destination, options: plan.options)
                    try fileManager.removeItem(at: source.path)
                }
                processedCount += 1
                onProgress(progress.recordProcessed(source))
            } catch {
                failedItems.append(try failedItemOrRethrowIfDisconnected(error, source: source))
            }
        }

        return OperationResult(
            success: failedItems.isEmpty,
            errorMessage: failedItems.isEmpty ? nil : "Some items failed to move",
            processedCount: processedCount,
            failedItems: failedItems
        )
    }

    // MARK: - copy/move helpers

    private enum ExistingDestinationResolution {
        case proceed
        case skip
    }

    /// If `destination` already exists, decides whether to remove it (so the caller can
    /// proceed) or skip this source, per `options.updateOnly`.
    private func resolveExistingDestination(
        source: FileEntry,
        destination: URL,
        options: CopyMoveOptions
    ) throws -> ExistingDestinationResolution {
        guard fileManager.fileExists(atPath: destination.path) else { return .proceed }

        if options.updateOnly {
            let destModified = (try? fileManager.attributesOfItem(atPath: destination.path))?[.modificationDate] as? Date
            if let destModified, destModified >= source.modificationDate {
                return .skip
            }
        }

        try fileManager.removeItem(at: destination)
        return .proceed
    }

    private func copySingleFile(_ source: FileEntry, to destination: URL, options: CopyMoveOptions) async throws {
        if source.isSymlink && !options.followSymlinks {
            let target = try fileManager.destinationOfSymbolicLink(atPath: source.path.path)
            try fileManager.createSymbolicLink(atPath: destination.path, withDestinationPath: target)
            return
        }

        try await withEBUSYRetry(url: source.path) {
            try copyItem(source.path, destination)
        }

        if options.preserveAttributes {
            var attributes: [FileAttributeKey: Any] = [:]
            if let sourceAttributes = try? fileManager.attributesOfItem(atPath: source.path.path) {
                attributes[.posixPermissions] = sourceAttributes[.posixPermissions]
                attributes[.modificationDate] = sourceAttributes[.modificationDate]
            }
            try? fileManager.setAttributes(attributes, ofItemAtPath: destination.path)
        }
    }

    /// Retries `operation` a few times, with a short backoff, when it fails with
    /// `POSIXError.EBUSY` (file in use by another process), per design.md's Error
    /// Handling Strategy. Throws a typed `.fileInUse` error once attempts are exhausted.
    private func withEBUSYRetry(url: URL, maxAttempts: Int = 3, _ operation: () throws -> Void) async throws {
        var attempt = 0
        while true {
            do {
                try operation()
                return
            } catch let error as POSIXError where error.code == .EBUSY {
                attempt += 1
                if attempt >= maxAttempts {
                    throw FileSystemServiceError.fileInUse(url)
                }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }
    }

    private func ensureSufficientSpace(for plan: CopyMovePlan) throws {
        let required = plan.sources.reduce(Int64(0)) { $0 + ($1.type == .directory ? 0 : $1.size) }
        let available = (try? availableFreeSpace(plan.destinationDirectory)) ?? Int64.max
        if available < required {
            throw FileSystemServiceError.insufficientDiskSpace
        }
    }

    /// Edge Case 7: throws `.pathTooLong` before starting the operation if any planned
    /// destination path would exceed the filesystem's `PATH_MAX`.
    private func ensureValidPathLengths(for plan: CopyMovePlan) throws {
        for source in plan.sources {
            let destination = plan.destinationDirectory.appendingPathComponent(plan.renames[source.id] ?? source.name)
            if destination.path.utf8.count > Int(PATH_MAX) {
                throw FileSystemServiceError.pathTooLong(destination)
            }
        }
    }

    /// Edge Case 6: a disconnected volume mid-operation (`POSIXError.ENOTCONN`) aborts
    /// the whole batch rather than being recorded as one more per-file failure - there's
    /// no point continuing to copy/move to or from a volume that just vanished. Any other
    /// error becomes a normal `FailedItem`, same as before.
    private func failedItemOrRethrowIfDisconnected(_ error: Error, source: FileEntry) throws -> FailedItem {
        if let posixError = error as? POSIXError, posixError.code == .ENOTCONN {
            throw FileSystemServiceError.volumeDisconnected(source.path)
        }
        return FailedItem(path: source.path.path, reason: describe(error))
    }

    private func describe(_ error: Error) -> String {
        if let typed = error as? FileSystemServiceError {
            return String(describing: typed)
        }
        return error.localizedDescription
    }

    // MARK: - getVolumes

    public func getVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeAvailableCapacityKey]
        let urls = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []

        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let name = values?.volumeName ?? url.lastPathComponent
            let freeSpace = Int64(values?.volumeAvailableCapacity ?? 0)
            return VolumeInfo(name: name, mountPoint: url, freeSpace: freeSpace)
        }
    }

    // SPEC_DEVIATION: `trash(_:)` is part of the `FileSystemService` protocol (Phase 1,
    // frozen) and design.md lists it as a Key Method of FileSystemServiceImpl, but no
    // task in T12-T14 owns it explicitly (the canonical, more thoroughly-tested
    // implementation is T15's `TrashServiceImpl`, conforming to the separate
    // `TrashService` protocol). Implemented here - minimally, using the same real
    // `FileManager.trashItem` API, not a stub - because `FileSystemServiceImpl` cannot
    // conform to `FileSystemService` (required for the type to be usable via the
    // protocol, e.g. by future ViewModels) without it.
    /// Moves `urls` to the system Trash.
    public func trash(_ urls: [URL]) async throws -> OperationResult {
        var failedItems: [FailedItem] = []
        var processedCount = 0

        for url in urls {
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                processedCount += 1
            } catch {
                failedItems.append(FailedItem(path: url.path, reason: error.localizedDescription))
            }
        }

        return OperationResult(
            success: failedItems.isEmpty,
            errorMessage: failedItems.isEmpty ? nil : "Some items could not be moved to Trash",
            processedCount: processedCount,
            failedItems: failedItems
        )
    }
}

extension FileSystemServiceImpl: FileSystemService {}

/// Accumulates copy/move progress across sources for the `onProgress` callback (FO-14):
/// running byte total, elapsed-time-based transfer speed, and a simple remaining-bytes /
/// speed ETA. A small reference type (not a struct) so `recordProcessed` can update
/// running totals without `copy`/`move` needing a mutable local var passed around.
final class OperationProgressTracker {
    private let totalFiles: Int
    private let totalBytes: Int64
    private let startTime: Date
    private let now: () -> Date
    private var bytesTransferred: Int64 = 0

    /// - Parameter now: injectable clock (defaults to the real `Date()`) so tests can
    ///   control elapsed time deterministically instead of racing a wall clock.
    init(sources: [FileEntry], now: @escaping () -> Date = Date.init) {
        totalFiles = sources.count
        totalBytes = sources.reduce(Int64(0)) { $0 + ($1.type == .directory ? 0 : $1.size) }
        self.now = now
        startTime = now()
    }

    /// Records `source` as processed and returns the resulting `OperationProgress`
    /// snapshot. `speed`/`eta` are `0` until any time has elapsed since construction.
    func recordProcessed(_ source: FileEntry) -> OperationProgress {
        bytesTransferred += source.type == .directory ? 0 : source.size
        let elapsed = now().timeIntervalSince(startTime)
        let speed = elapsed > 0 ? Double(bytesTransferred) / elapsed : 0
        let remainingBytes = totalBytes - bytesTransferred
        let eta = speed > 0 ? Double(remainingBytes) / speed : 0
        return OperationProgress(
            currentFile: source.name,
            totalFiles: totalFiles,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
            speed: speed,
            eta: eta
        )
    }
}
