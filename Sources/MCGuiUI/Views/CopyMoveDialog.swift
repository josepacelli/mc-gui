import SwiftUI
import MCGuiCore

/// The F5 (copy) / F6 (move) dialog: destination field, copy/move option checkboxes, and
/// confirm/cancel actions bound to `CopyMoveDialogViewModel` (FO-01, FO-02).
public struct CopyMoveDialog: View {
    @Bindable public var viewModel: CopyMoveDialogViewModel
    public var onConfirm: () -> Void
    // FO-14 (classic mc parity): the original always shows the progress dialog on a
    // normal OK - "Segundo plano" is the one explicit opt-in that runs silently instead,
    // per user request ("mc original so usa a opcao segundo plano quando pedido").
    public var onConfirmBackground: () -> Void
    public var onCancel: () -> Void

    public init(
        viewModel: CopyMoveDialogViewModel,
        onConfirm: @escaping () -> Void = {},
        onConfirmBackground: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onConfirm = onConfirm
        self.onConfirmBackground = onConfirmBackground
        self.onCancel = onCancel
    }

    private var title: String {
        viewModel.mode == .copy ? "Copy" : "Move"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(title) \(viewModel.sources.count) item\(viewModel.sources.count == 1 ? "" : "s")")
                .font(.headline)

            TextField("Destination", text: Binding(
                get: { viewModel.destinationDirectory.path },
                set: { viewModel.destinationDirectory = URL(fileURLWithPath: $0) }
            ))
            .textFieldStyle(.roundedBorder)

            Toggle("Preserve attributes", isOn: $viewModel.options.preserveAttributes)
            Toggle("Follow symlinks", isOn: $viewModel.options.followSymlinks)
            Toggle("Update only (skip up-to-date files)", isOn: $viewModel.options.updateOnly)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Background", action: onConfirmBackground)
                Button(title, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 360)
    }
}
