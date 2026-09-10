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

    /// Copies `plan.sources` into `plan.destinationDirectory`.
    ///
    /// Conflict handling (FO-06/FO-07): with `updateOnly == false` an existing
    /// destination entry is always overwritten; with `updateOnly == true` it is
    /// overwritten only when the source is newer, otherwise skipped. Renaming
    /// (FO-08) and cancelling (FO-09) are resolved upstream, before the plan reaches
    /// this method - `plan.sources`/`destinationDirectory` already reflect that choice.
    public func copy(_ plan: CopyMovePlan) async throws -> OperationResult {
        try ensureSufficientSpace(for: plan)

        var failedItems: [FailedItem] = []
        var processedCount = 0

        for source in plan.sources {
            let destination = plan.destinationDirectory.appendingPathComponent(plan.renames[source.id] ?? source.name)
            do {
                if try resolveExistingDestination(source: source, destination: destination, options: plan.options) == .skip {
                    processedCount += 1
                    continue
                }

                try await copySingleFile(source, to: destination, options: plan.options)
                processedCount += 1
            } catch {
                failedItems.append(FailedItem(path: source.path.path, reason: describe(error)))
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

    /// Moves `plan.sources` into `plan.destinationDirectory`: renames within the same
    /// volume, copies then deletes the original across volumes (FO-04).
    public func move(_ plan: CopyMovePlan) async throws -> OperationResult {
        try ensureSufficientSpace(for: plan)

        var failedItems: [FailedItem] = []
        var processedCount = 0

        for source in plan.sources {
            let destination = plan.destinationDirectory.appendingPathComponent(plan.renames[source.id] ?? source.name)
            do {
                if try resolveExistingDestination(source: source, destination: destination, options: plan.options) == .skip {
                    processedCount += 1
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
            } catch {
                failedItems.append(FailedItem(path: source.path.path, reason: describe(error)))
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
