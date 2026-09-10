import Foundation
import Observation
import MCGuiCore

/// Resolves a single filename conflict at `destinationPath`, returning the user's choice.
/// Callers back this with a `ConflictDialogViewModel` presented to the user (FO-05..FO-09).
public typealias ConflictResolver = @MainActor (URL) async -> FileConflictResolution

/// The F5 (copy) / F6 (move) dialog's state: source files, destination, and copy/move
/// options, delegating any destination-already-exists conflict to a `ConflictDialogViewModel`
/// via the injected `resolveConflict` (FO-01..FO-04).
///
/// This ViewModel only holds configuration and conflict delegation - it does not itself
/// invoke `FileSystemService.copy`/`move`; that wiring against the panel's already-injected
/// `FileSystemService` happens where the dialog is presented (Phase 6, T33).
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

    /// Delegates the conflict at `destinationPath` to whatever `ConflictDialogViewModel`
    /// (or test double) was wired in via `resolveConflict`.
    public func resolveConflict(at destinationPath: URL) async -> FileConflictResolution {
        await resolveConflictHandler(destinationPath)
    }
}
