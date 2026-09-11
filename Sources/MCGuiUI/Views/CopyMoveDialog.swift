import SwiftUI
import MCGuiCore

@MainActor
public struct CopyMoveDialog: View {
    @Bindable public var viewModel: CopyMoveDialogViewModel
    public var onConfirm: () -> Void
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
        viewModel.mode == .copy
            ? String(localized: "copyMove.title.copy", bundle: .module, comment: "F5 dialog title/button: Copy")
            : String(localized: "copyMove.title.move", bundle: .module, comment: "F6 dialog title/button: Move")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    format: NSLocalizedString(
                        viewModel.sources.count == 1 ? "copyMove.header.singular" : "copyMove.header.plural",
                        bundle: .module,
                        comment: "Copy/Move dialog header. %1$@ is the localized mode word (Copy/Move), %2$d is the item count."
                    ),
                    title, viewModel.sources.count
                )
            )
            .font(.headline)

            TextField(
                String(localized: "copyMove.field.destination", bundle: .module, comment: "Destination path text field label"),
                text: Binding(
                    get: { viewModel.destinationDirectory.path },
                    set: { viewModel.destinationDirectory = URL(fileURLWithPath: $0) }
                )
            )
            .textFieldStyle(.roundedBorder)

            Toggle(
                String(localized: "copyMove.toggle.preserveAttributes", bundle: .module, comment: "Preserve file attributes checkbox"),
                isOn: $viewModel.options.preserveAttributes
            )
            Toggle(
                String(localized: "copyMove.toggle.followSymlinks", bundle: .module, comment: "Follow symlinks checkbox"),
                isOn: $viewModel.options.followSymlinks
            )
            Toggle(
                String(localized: "copyMove.toggle.updateOnly", bundle: .module, comment: "Update-only (skip up-to-date files) checkbox"),
                isOn: $viewModel.options.updateOnly
            )

            HStack {
                Spacer()
                Button(String(localized: "copyMove.button.cancel", bundle: .module, comment: "Cancel button"), role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "copyMove.button.background", bundle: .module, comment: "Run in background button"), action: onConfirmBackground)
                Button(title, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 360)
    }
}
