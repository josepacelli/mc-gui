import SwiftUI
import MCGuiCore

/// The F7 new-folder dialog: a name field and Create/Cancel actions bound to
/// `MkdirDialogViewModel` (FO-10).
@MainActor
public struct MkdirDialog: View {
    @Bindable public var viewModel: MkdirDialogViewModel
    public var onCancel: () -> Void

    public init(viewModel: MkdirDialogViewModel, onCancel: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onCancel = onCancel
    }

    private var isNameValid: Bool {
        MkdirDialogViewModel.validate(viewModel.name) == nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "mkdir.title", bundle: .module, comment: "F7 dialog title: New Folder"))
                .font(.headline)

            TextField(
                String(localized: "mkdir.field.name", bundle: .module, comment: "Folder name text field label"),
                text: $viewModel.name
            )
            .textFieldStyle(.roundedBorder)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(String(localized: "mkdir.button.cancel", bundle: .module, comment: "Cancel button"), role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "mkdir.button.create", bundle: .module, comment: "Create folder button")) {
                    Task { await viewModel.confirm() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isNameValid)
            }
        }
        .padding()
        .frame(minWidth: 280)
    }
}
