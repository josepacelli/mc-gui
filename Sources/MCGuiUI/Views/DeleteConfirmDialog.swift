import SwiftUI
import MCGuiCore

/// The F8 delete-confirmation dialog: lists the files about to be trashed, with a
/// Trash-bound confirm action (FO-12, FO-13).
public struct DeleteConfirmDialog: View {
    public let viewModel: DeleteConfirmDialogViewModel
    public var onCancel: () -> Void

    public init(viewModel: DeleteConfirmDialogViewModel, onCancel: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move \(viewModel.count) item\(viewModel.count == 1 ? "" : "s") to Trash?")
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
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Move to Trash") {
                    Task { await viewModel.confirm() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}
