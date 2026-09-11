import Foundation
import Observation
import MCGuiCore

public typealias ConflictResolver = @MainActor (URL) async -> FileConflictResolution

@MainActor
@Observable
public final class CopyMoveDialogViewModel {
    public let sources: [FileEntry]
    public let mode: OperationMode
    public var destinationDirectory: URL
    public var options: CopyMoveOptions

    private let resolveConflictHandler: ConflictResolver

    public init(
        sources: [FileEntry],
        destinationDirectory: URL,
        mode: OperationMode,
        options: CopyMoveOptions,
        resolveConflict: @escaping ConflictResolver = { _ in .cancel }
    ) {
        self.sources = sources
        self.destinationDirectory = destinationDirectory
        self.mode = mode
        self.options = options
        self.resolveConflictHandler = resolveConflict
    }

    public func resolveConflict(at destinationPath: URL) async -> FileConflictResolution {
        await resolveConflictHandler(destinationPath)
    }
}
