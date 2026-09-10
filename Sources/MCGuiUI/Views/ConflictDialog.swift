import SwiftUI
import MCGuiCore

/// The file-conflict dialog: Overwrite/Skip/Rename/Cancel buttons for a destination file
/// that already exists, bound to `ConflictDialogViewModel` (FO-05..FO-09).
public struct ConflictDialog: View {
    public let viewModel: ConflictDialogViewModel

    public init(viewModel: ConflictDialogViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\"\(viewModel.destinationPath.lastPathComponent)\" already exists")
                .font(.headline)
            Text(viewModel.destinationPath.deletingLastPathComponent().path)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel", role: .cancel) { viewModel.chooseCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Skip") { viewModel.chooseSkip() }
                Button("Rename") { viewModel.chooseRename() }
                Button("Overwrite") { viewModel.chooseOverwrite() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 360)
    }
}
