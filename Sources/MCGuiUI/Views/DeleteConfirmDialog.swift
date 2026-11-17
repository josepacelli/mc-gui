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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.red)
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
            }

            List(viewModel.entries) { entry in
                HStack(spacing: 8) {
                    FileIcon(type: entry.type)
                    Text(entry.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .listStyle(.inset)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
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
                Button(String(localized: "deleteConfirm.button.confirm", bundle: .module, comment: "Move to Trash confirm button"), role: .destructive) {
                    Task { await viewModel.confirm() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}
