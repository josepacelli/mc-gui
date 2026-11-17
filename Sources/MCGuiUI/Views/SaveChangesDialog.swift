import SwiftUI

@MainActor
public struct SaveChangesDialog: View {
    public let viewModel: SaveChangesDialogViewModel

    public init(viewModel: SaveChangesDialogViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.ellipsis")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(viewModel.message)
                    .font(.headline)
            }

            HStack {
                Button(String(localized: "saveChanges.button.cancel", bundle: .module, comment: "Cancel button"), role: .cancel) { viewModel.chooseCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(String(localized: "saveChanges.button.dontSave", bundle: .module, comment: "Don't Save (discard changes) button"), role: .destructive) { viewModel.chooseDiscard() }
                Button(String(localized: "saveChanges.button.save", bundle: .module, comment: "Save button")) { viewModel.chooseSave() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
    }
}
