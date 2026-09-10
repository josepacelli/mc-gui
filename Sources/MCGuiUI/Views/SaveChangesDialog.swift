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
                Button("Cancel", role: .cancel) { viewModel.chooseCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Don't Save", role: .destructive) { viewModel.chooseDiscard() }
                Button("Save") { viewModel.chooseSave() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 360)
    }
}
