import Foundation

public struct FileEntry: Identifiable, Hashable, Codable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let size: Int64
    public let creationDate: Date
    public let modificationDate: Date
    public let permissions: FilePermissions
    public let type: FileType
    public let isHidden: Bool
    public let isSymlink: Bool
    public let symlinkTarget: URL?

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        size: Int64,
        creationDate: Date,
        modificationDate: Date,
        permissions: FilePermissions,
        type: FileType,
        isHidden: Bool,
        isSymlink: Bool,
        symlinkTarget: URL?
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.permissions = permissions
        self.type = type
        self.isHidden = isHidden
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
    }
}

public enum FileType: String, Codable, CaseIterable {
    case file, directory, symlink, volume, unknown
}

public struct FilePermissions: OptionSet, Codable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let ownerRead = FilePermissions(rawValue: 1 << 0)
    public static let ownerWrite = FilePermissions(rawValue: 1 << 1)
    public static let ownerExecute = FilePermissions(rawValue: 1 << 2)
    public static let groupRead = FilePermissions(rawValue: 1 << 3)
    public static let groupWrite = FilePermissions(rawValue: 1 << 4)
    public static let groupExecute = FilePermissions(rawValue: 1 << 5)
    public static let otherRead = FilePermissions(rawValue: 1 << 6)
    public static let otherWrite = FilePermissions(rawValue: 1 << 7)
    public static let otherExecute = FilePermissions(rawValue: 1 << 8)
}
