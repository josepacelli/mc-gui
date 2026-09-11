import Foundation
import Observation
import MCGuiCore

/// The F8 delete-confirmation dialog's state: the files about to be deleted and a confirm
/// action that moves them to Trash via the injected `TrashService` (FO-12, FO-13).
@MainActor
@Observable
public final class DeleteConfirmDialogViewModel {
    private let trashService: TrashService
    public let entries: [FileEntry]

    public private(set) var result: OperationResult?
    public private(set) var errorMessage: String?
    public private(set) var isCompleted = false

    public init(trashService: TrashService, entries: [FileEntry]) {
        self.trashService = trashService
        self.entries = entries
    }

    public var count: Int { entries.count }

    /// Moves `entries` to Trash (FO-13). Guards against an empty selection - there is
    /// nothing to confirm - by setting `errorMessage` and making no `TrashService` call.
    public func confirm() async {
        guard !entries.isEmpty else {
            errorMessage = String(localized: "deleteConfirmValidation.noSelection", bundle: .module, comment: "F8 dialog: confirm() was called with an empty selection")
            return
        }

        errorMessage = nil
        do {
            result = try await trashService.trash(entries.map(\.path))
            isCompleted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
