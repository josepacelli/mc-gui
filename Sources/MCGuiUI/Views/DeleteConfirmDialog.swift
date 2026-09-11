import SwiftUI
import MCGuiCore

@MainActor
public struct DeleteConfirmDialog: View {
    public let viewModel: DeleteConfirmDialogViewModel
    public var onCancel: () -> Void

    public init(viewModel: DeleteConfirmDialogViewModel, onCancel: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    format: NSLocalizedString(
                        viewModel.count == 1 ? "deleteConfirm.header.singular" : "deleteConfirm.header.plural",
                        bundle: .module,
                        comment: "F8 delete-confirmation header. %1$d is the item count."
                    ),
                    viewModel.count
                )
            )
            .font(.headline)

            List(viewModel.entries) { entry in
                Text(entry.name)
            }
            .frame(minHeight: 100, maxHeight: 200)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(String(localized: "deleteConfirm.button.cancel", bundle: .module, comment: "Cancel button"), role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "deleteConfirm.button.confirm", bundle: .module, comment: "Move to Trash confirm button")) {
                    Task { await viewModel.confirm() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}
