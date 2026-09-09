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

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
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
}
