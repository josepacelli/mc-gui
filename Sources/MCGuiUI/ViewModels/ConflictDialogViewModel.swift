import Foundation
import Observation
import MCGuiCore

/// The file-conflict resolution dialog's state (FO-05..FO-09): the user picks one of
/// Overwrite/Skip/Rename/Cancel for the file already present at `destinationPath`, and the
/// choice is both recorded on `resolution` and reported via `onResolve` (so a caller such
/// as `CopyMoveDialogViewModel` can await it).
@MainActor
@Observable
public final class ConflictDialogViewModel {
    public let destinationPath: URL
    public private(set) var resolution: FileConflictResolution?
    private let onResolve: (FileConflictResolution) -> Void

    public init(destinationPath: URL, onResolve: @escaping (FileConflictResolution) -> Void = { _ in }) {
        self.destinationPath = destinationPath
        self.onResolve = onResolve
    }

    public func chooseOverwrite() { resolve(.overwrite) }
    public func chooseSkip() { resolve(.skip) }
    public func chooseRename() { resolve(.rename) }
    public func chooseCancel() { resolve(.cancel) }

    private func resolve(_ value: FileConflictResolution) {
        resolution = value
        onResolve(value)
    }
}
