import Foundation

/// Whether a file operation copies or moves its sources.
public enum OperationMode: String, Codable, CaseIterable {
    case copy, move
}

/// User-configurable behavior for a copy or move operation.
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

// SPEC_DEVIATION: design.md's illustrative Swift code block for CopyMovePlan includes
// `sourcePanel: PanelSide`, but PanelSide has no owning task in Phase 1 (it first appears
// as a `Reuses` citation in T17, Phase 4) and T4's "Done when" list does not require a
// sourcePanel field. Using the design's prose description ("source, destination, options,
// files array") and the C# reference model (CopyMovePlan.cs: Sources, DestinationDirectory,
// Mode) instead, so this type does not depend on a type not yet introduced.
/// A plan for copying or moving a set of files to a destination directory.
public struct CopyMovePlan: Codable {
    public var sources: [FileEntry]
    public var destinationDirectory: URL
    public var mode: OperationMode
    public var options: CopyMoveOptions
    // FO-08: per-source destination filename override (keyed by `FileEntry.id`), set by
    // the caller when the user picked "Rename" for a conflicting file
    // (`CopyMovePlanner.resolvedName`). Sources absent here use their own `name`
    // unchanged - the common case, so existing callers building a plan without conflicts
    // don't need to know this field exists.
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

/// A snapshot of an in-progress copy/move operation, suitable for progress UI.
public struct OperationProgress: Codable, Hashable {
    public var currentFile: String
    // FO-14: how many sources have been processed so far, out of `totalFiles` - lets the
    // progress dialog show "file N of M", not just a byte-based progress bar. Defaults to
    // 0 for existing callers that don't track it explicitly.
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

/// One file that failed during a copy/move/delete operation, with the reason.
public struct FailedItem: Codable, Hashable {
    public var path: String
    public var reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

/// The outcome of a completed (or partially completed) file operation.
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
