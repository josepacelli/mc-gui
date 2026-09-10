import Foundation
import Observation

/// The user's choice when prompted to save unsaved editor changes before closing
/// (ED-05..ED-08).
public enum SaveChangesResult: Equatable {
    case save, discard, cancel
}

/// The close-with-unsaved-changes prompt's state: the user picks Save/Don't Save/Cancel
/// for `fileName`, and the choice is both recorded on `result` and reported via
/// `onResolve` (so a caller such as `EditorWindow`, T43, can react to it).
@MainActor
@Observable
public final class SaveChangesDialogViewModel {
    public let fileName: String
    public private(set) var result: SaveChangesResult?
    private let onResolve: (SaveChangesResult) -> Void

    public init(fileName: String, onResolve: @escaping (SaveChangesResult) -> Void = { _ in }) {
        self.fileName = fileName
        self.onResolve = onResolve
    }

    public var message: String {
        String(format: NSLocalizedString("saveChangesPrompt.message", bundle: .module, comment: "Prompt asking to save unsaved changes before closing. %1$@ is the file name."), fileName)
    }

    public func chooseSave() { resolve(.save) }
    public func chooseDiscard() { resolve(.discard) }
    public func chooseCancel() { resolve(.cancel) }

    private func resolve(_ value: SaveChangesResult) {
        result = value
        onResolve(value)
    }
}
