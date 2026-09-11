import Foundation
import Observation
import MCGuiCore

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
