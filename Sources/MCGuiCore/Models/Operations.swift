import Foundation

public enum OperationMode: String, Codable, CaseIterable {
    case copy, move
}

public struct CopyMoveOptions: Codable, Hashable {
    public var preserveAttributes: Bool
    public var followSymlinks: Bool
    public var updateOnly: Bool

    public init(preserveAttributes: Bool, followSymlinks: Bool, updateOnly: Bool) {
        self.preserveAttributes = preserveAttributes
        self.followSymlinks = followSymlinks
        self.updateOnly = updateOnly
    }
}

public struct CopyMovePlan: Codable {
    public var sources: [FileEntry]
    public var destinationDirectory: URL
    public var mode: OperationMode
    public var options: CopyMoveOptions
    public var renames: [UUID: String]

    public init(
        sources: [FileEntry],
        destinationDirectory: URL,
        mode: OperationMode,
        options: CopyMoveOptions,
        renames: [UUID: String] = [:]
    ) {
        self.sources = sources
        self.destinationDirectory = destinationDirectory
        self.mode = mode
        self.options = options
        self.renames = renames
    }
}

public struct OperationProgress: Codable, Hashable {
    public var currentFile: String
    public var filesProcessed: Int
    public var totalFiles: Int
    public var bytesTransferred: Int64
    public var totalBytes: Int64
    public var speed: Double
    public var eta: TimeInterval

    public init(
        currentFile: String,
        filesProcessed: Int = 0,
        totalFiles: Int,
        bytesTransferred: Int64,
        totalBytes: Int64,
        speed: Double,
        eta: TimeInterval
    ) {
        self.currentFile = currentFile
        self.filesProcessed = filesProcessed
        self.totalFiles = totalFiles
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
        self.speed = speed
        self.eta = eta
    }
}

public struct FailedItem: Codable, Hashable {
    public var path: String
    public var reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

public struct OperationResult: Codable, Hashable {
    public var success: Bool
    public var errorMessage: String?
    public var processedCount: Int
    public var failedItems: [FailedItem]

    public init(success: Bool, errorMessage: String?, processedCount: Int, failedItems: [FailedItem]) {
        self.success = success
        self.errorMessage = errorMessage
        self.processedCount = processedCount
        self.failedItems = failedItems
    }
}
