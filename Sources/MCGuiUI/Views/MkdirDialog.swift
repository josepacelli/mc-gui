import SwiftUI
import MCGuiCore

/// The F7 new-folder dialog: a name field and Create/Cancel actions bound to
/// `MkdirDialogViewModel` (FO-10).
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
            Text("New Folder")
                .font(.headline)

            TextField("Folder name", text: $viewModel.name)
                .textFieldStyle(.roundedBorder)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
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
