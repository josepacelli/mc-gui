import SwiftUI

/// The close-with-unsaved-changes prompt: Save/Don't Save/Cancel buttons bound to
/// `SaveChangesDialogViewModel` (ED-05..ED-08).
public struct SaveChangesDialog: View {
    public let viewModel: SaveChangesDialogViewModel

    public init(viewModel: SaveChangesDialogViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.message)
                .font(.headline)

            HStack {
                Button(String(localized: "saveChanges.button.cancel", bundle: .module, comment: "Cancel button"), role: .cancel) { viewModel.chooseCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(String(localized: "saveChanges.button.dontSave", bundle: .module, comment: "Don't Save (discard changes) button"), role: .destructive) { viewModel.chooseDiscard() }
                Button(String(localized: "saveChanges.button.save", bundle: .module, comment: "Save button")) { viewModel.chooseSave() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 360)
    }
}
