import SwiftUI
import MCGuiCore

/// The in-progress copy/move/delete dialog: a progress bar, current file, transfer speed,
/// ETA, and a Cancel button bound to `ProgressDialogViewModel` (FO-14, FO-16).
public struct ProgressDialog: View {
    public let viewModel: ProgressDialogViewModel

    public init(viewModel: ProgressDialogViewModel) {
        self.viewModel = viewModel
    }

    private var fraction: Double {
        guard viewModel.totalBytes > 0 else { return 0 }
        return Double(viewModel.bytesTransferred) / Double(viewModel.totalBytes)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Copying…")
                .font(.headline)

            ProgressView(value: fraction)

            Text(viewModel.currentFile)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                Text(ByteCountFormatter.string(fromByteCount: viewModel.bytesTransferred, countStyle: .file))
                Text("of")
                Text(ByteCountFormatter.string(fromByteCount: viewModel.totalBytes, countStyle: .file))
                Spacer()
                Text("\(Int(viewModel.eta))s remaining")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { viewModel.cancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}
