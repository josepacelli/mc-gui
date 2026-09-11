import SwiftUI
import MCGuiCore

@MainActor
public struct ConflictDialog: View {
    public let viewModel: ConflictDialogViewModel

    public init(viewModel: ConflictDialogViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    format: NSLocalizedString(
                        "conflictDialog.header.alreadyExists",
                        bundle: .module,
                        comment: "Conflict dialog header. %1$@ is the conflicting destination file's name."
                    ),
                    viewModel.destinationPath.lastPathComponent
                )
            )
            .font(.headline)
            Text(viewModel.destinationPath.deletingLastPathComponent().path)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(String(localized: "conflictDialog.button.cancel", bundle: .module, comment: "Cancel button"), role: .cancel) { viewModel.chooseCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(String(localized: "conflictDialog.button.skip", bundle: .module, comment: "Skip button")) { viewModel.chooseSkip() }
                Button(String(localized: "conflictDialog.button.rename", bundle: .module, comment: "Rename button")) { viewModel.chooseRename() }
                Button(String(localized: "conflictDialog.button.overwrite", bundle: .module, comment: "Overwrite button")) { viewModel.chooseOverwrite() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 360)
    }
}
