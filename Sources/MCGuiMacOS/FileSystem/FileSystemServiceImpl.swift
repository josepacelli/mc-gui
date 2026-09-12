import Foundation
import MCGuiCore

public enum FileSystemServiceError: Error, Equatable {
    case permissionDenied(URL)
    case alreadyExists(URL)
    case fileInUse(URL)
    case insufficientDiskSpace
    case volumeDisconnected(URL)
    case pathTooLong(URL)
    case zipFailed(reason: String)
}

extension FileSystemServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let url):
            return String(
                format: NSLocalizedString(
                    "fileSystemError.permissionDenied",
                    bundle: .module,
                    comment: "Directory/file read permission denied. %1$@ is the file path."
                ),
                url.path
            )
        case .alreadyExists(let url):
            return String(
                format: NSLocalizedString(
                    "fileSystemError.alreadyExists",
                    bundle: .module,
                    comment: "createDirectory target already exists. %1$@ is the file path."
                ),
                url.path
            )
        case .fileInUse(let url):
            return String(
                format: NSLocalizedString(
                    "fileSystemError.fileInUse",
                    bundle: .module,
                    comment: "File is locked/in use by another process. %1$@ is the file path."
                ),
                url.path
            )
        case .insufficientDiskSpace:
            return NSLocalizedString(
                "fileSystemError.insufficientDiskSpace",
                bundle: .module,
                comment: "Not enough free space at the destination."
            )
        case .volumeDisconnected(let url):
            return String(
                format: NSLocalizedString(
                    "fileSystemError.volumeDisconnected",
                    bundle: .module,
                    comment: "The volume was disconnected mid-operation. %1$@ is the file path that was on that volume."
                ),
                url.path
            )
        case .pathTooLong(let url):
            return String(
                format: NSLocalizedString(
                    "fileSystemError.pathTooLong",
                    bundle: .module,
                    comment: "A planned destination path exceeds PATH_MAX. %1$@ is the destination path."
                ),
                url.path
            )
        case .zipFailed(let reason):
            return String(
                format: NSLocalizedString(
                    "fileSystemError.zipFailed",
                    bundle: .module,
                    comment: "zip process exited non-zero. %1$@ is the failure reason (process stderr)."
                ),
                reason
            )
        }
    }
}

public final class FileSystemServiceImpl {
    private let fileManager: FileManager
    private let copyItem: (URL, URL) throws -> Void
    private let moveItem: (URL, URL) throws -> Void
    private let availableFreeSpace: (URL) throws -> Int64
    private let isSameVolume: (URL, URL) -> Bool

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


    public func createDirectory(_ url: URL) async throws {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        } catch let error as CocoaError where error.code == .fileWriteFileExists {
            throw FileSystemServiceError.alreadyExists(url)
        }
    }


    public func copy(_ plan: CopyMovePlan) async throws -> OperationResult {
        try await copy(plan, onProgress: { _ in })
    }

    public func copy(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult {
        try ensureSufficientSpace(for: plan)
        try ensureValidPathLengths(for: plan)

        var failedItems: [FailedItem] = []
        var processedCount = 0
        let progress = OperationProgressTracker(sources: expandedFiles(for: plan.sources))

        for source in plan.sources {
            try Task.checkCancellation()
            let destination = plan.destinationDirectory.appendingPathComponent(plan.renames[source.id] ?? source.name)
            do {
                if try resolveExistingDestination(source: source, destination: destination, options: plan.options) == .skip {
                    processedCount += 1
                    onProgress(progress.recordProcessed(source))
                    continue
                }

                if source.type == .directory {
                    try await copyDirectoryContents(source, to: destination, options: plan.options, progress: progress, onProgress: onProgress)
                } else {
                    try await copySingleFile(source, to: destination, options: plan.options)
                    onProgress(progress.recordProcessed(source))
                }
                processedCount += 1
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedItems.append(try failedItemOrRethrowIfDisconnected(error, source: source))
            }
        }

        return OperationResult(
            success: failedItems.isEmpty,
            errorMessage: failedItems.isEmpty ? nil : String(localized: "operationResult.error.copyFailed", bundle: .module, comment: "Summary error when one or more items failed to copy"),
            processedCount: processedCount,
            failedItems: failedItems
        )
    }


    public func move(_ plan: CopyMovePlan) async throws -> OperationResult {
        try await move(plan, onProgress: { _ in })
    }

    public func move(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult {
        try ensureSufficientSpace(for: plan)
        try ensureValidPathLengths(for: plan)

        var failedItems: [FailedItem] = []
        var processedCount = 0
        let progress = OperationProgressTracker(sources: expandedFiles(for: plan.sources))

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
                    if source.type == .directory {
                        reportCompletedDirectory(at: destination, progress: progress, onProgress: onProgress)
                    } else {
                        onProgress(progress.recordProcessed(source))
                    }
                } else if source.type == .directory {
                    try await copyDirectoryContents(source, to: destination, options: plan.options, progress: progress, onProgress: onProgress)
                    try fileManager.removeItem(at: source.path)
                } else {
                    try await copySingleFile(source, to: destination, options: plan.options)
                    try fileManager.removeItem(at: source.path)
                    onProgress(progress.recordProcessed(source))
                }
                processedCount += 1
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedItems.append(try failedItemOrRethrowIfDisconnected(error, source: source))
            }
        }

        return OperationResult(
            success: failedItems.isEmpty,
            errorMessage: failedItems.isEmpty ? nil : String(localized: "operationResult.error.moveFailed", bundle: .module, comment: "Summary error when one or more items failed to move"),
            processedCount: processedCount,
            failedItems: failedItems
        )
    }


    private enum ExistingDestinationResolution {
        case proceed
        case skip
    }

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

    private static let directoryWalkKeys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]

    private func lightEntry(for url: URL, keys: Set<URLResourceKey> = Set(directoryWalkKeys)) -> FileEntry {
        let values = try? url.resourceValues(forKeys: keys)
        let isDirectory = values?.isDirectory ?? false
        let isSymlink = values?.isSymbolicLink ?? false
        let size = Int64(values?.fileSize ?? 0)
        let type: FileType = isSymlink ? .symlink : (isDirectory ? .directory : .file)
        return FileEntry(
            name: url.lastPathComponent,
            path: url,
            size: size,
            creationDate: .distantPast,
            modificationDate: .distantPast,
            permissions: [],
            type: type,
            isHidden: false,
            isSymlink: isSymlink,
            symlinkTarget: nil
        )
    }

    private func expandedFiles(for sources: [FileEntry]) -> [FileEntry] {
        var result: [FileEntry] = []
        for source in sources {
            guard source.type == .directory else {
                result.append(source)
                continue
            }
            let enumerator = fileManager.enumerator(at: source.path, includingPropertiesForKeys: Self.directoryWalkKeys, options: [])
            while let url = enumerator?.nextObject() as? URL {
                let entry = lightEntry(for: url)
                guard entry.type != .directory else { continue }
                result.append(entry)
            }
        }
        return result
    }

    private func copyDirectoryContents(
        _ source: FileEntry,
        to destination: URL,
        options: CopyMoveOptions,
        progress: OperationProgressTracker,
        onProgress: (OperationProgress) -> Void
    ) async throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        let sourceDepth = source.path.pathComponents.count
        let enumerator = fileManager.enumerator(at: source.path, includingPropertiesForKeys: Self.directoryWalkKeys, options: [])

        while let url = enumerator?.nextObject() as? URL {
            try Task.checkCancellation()
            let relativeComponents = url.pathComponents.dropFirst(sourceDepth)
            let itemDestination = relativeComponents.reduce(destination) { $0.appendingPathComponent($1) }
            let entry = lightEntry(for: url)

            if entry.type == .directory {
                try fileManager.createDirectory(at: itemDestination, withIntermediateDirectories: true)
                continue
            }

            try await copySingleFile(entry, to: itemDestination, options: options)
            onProgress(progress.recordProcessed(entry))
        }
    }

    private func reportCompletedDirectory(
        at destination: URL,
        progress: OperationProgressTracker,
        onProgress: (OperationProgress) -> Void
    ) {
        let enumerator = fileManager.enumerator(at: destination, includingPropertiesForKeys: Self.directoryWalkKeys, options: [])
        while let url = enumerator?.nextObject() as? URL {
            let entry = lightEntry(for: url)
            guard entry.type != .directory else { continue }
            onProgress(progress.recordProcessed(entry))
        }
    }

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

    private func ensureValidPathLengths(for plan: CopyMovePlan) throws {
        for source in plan.sources {
            let destination = plan.destinationDirectory.appendingPathComponent(plan.renames[source.id] ?? source.name)
            if destination.path.utf8.count > Int(PATH_MAX) {
                throw FileSystemServiceError.pathTooLong(destination)
            }
        }
    }

    private func failedItemOrRethrowIfDisconnected(_ error: Error, source: FileEntry) throws -> FailedItem {
        if let posixError = error as? POSIXError, posixError.code == .ENOTCONN {
            throw FileSystemServiceError.volumeDisconnected(source.path)
        }
        return FailedItem(path: source.path.path, reason: describe(error))
    }

    private func describe(_ error: Error) -> String {
        if let typed = error as? FileSystemServiceError {
            return typed.errorDescription ?? typed.localizedDescription
        }
        return error.localizedDescription
    }


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

    public func zip(_ sources: [FileEntry], to destination: URL) async throws {
        guard let parentDirectory = sources.first?.path.deletingLastPathComponent() else { return }

        let tempURL = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).partial")
        try? fileManager.removeItem(at: tempURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = parentDirectory
        process.arguments = ["-r", "-X", "-y", tempURL.path] + sources.map(\.name)

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw FileSystemServiceError.zipFailed(reason: error.localizedDescription)
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderrText = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            try? fileManager.removeItem(at: tempURL)
            throw FileSystemServiceError.zipFailed(
                reason: (stderrText?.isEmpty == false ? stderrText : nil) ?? "zip exited with status \(process.terminationStatus)"
            )
        }

        try fileManager.moveItem(at: tempURL, to: destination)
    }

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
            errorMessage: failedItems.isEmpty ? nil : String(localized: "operationResult.error.trashFailed", bundle: .module, comment: "Summary error when one or more items could not be moved to Trash"),
            processedCount: processedCount,
            failedItems: failedItems
        )
    }
}

extension FileSystemServiceImpl: FileSystemService {}

final class OperationProgressTracker {
    private let totalFiles: Int
    private let totalBytes: Int64
    private let startTime: Date
    private let now: () -> Date
    private var bytesTransferred: Int64 = 0
    private var filesProcessed: Int = 0

    init(sources: [FileEntry], now: @escaping () -> Date = Date.init) {
        totalFiles = sources.count
        totalBytes = sources.reduce(Int64(0)) { $0 + ($1.type == .directory ? 0 : $1.size) }
        self.now = now
        startTime = now()
    }

    func recordProcessed(_ source: FileEntry) -> OperationProgress {
        bytesTransferred += source.type == .directory ? 0 : source.size
        filesProcessed += 1
        let elapsed = now().timeIntervalSince(startTime)
        let speed = elapsed > 0 ? Double(bytesTransferred) / elapsed : 0
        let remainingBytes = totalBytes - bytesTransferred
        let eta = speed > 0 ? Double(remainingBytes) / speed : 0
        return OperationProgress(
            currentFile: source.name,
            filesProcessed: filesProcessed,
            totalFiles: totalFiles,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
            speed: speed,
            eta: eta
        )
    }
}
