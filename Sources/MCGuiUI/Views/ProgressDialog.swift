import SwiftUI
import MCGuiCore

@MainActor
public struct ProgressDialog: View {
    public let viewModel: ProgressDialogViewModel

    public init(viewModel: ProgressDialogViewModel) {
        self.viewModel = viewModel
    }

    private var fraction: Double {
        guard viewModel.totalBytes > 0 else { return 0 }
        return Double(viewModel.bytesTransferred) / Double(viewModel.totalBytes)
    }

    private var isScanning: Bool {
        !viewModel.isCompleted && viewModel.totalFiles == 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "progress.title.copying", bundle: .module, comment: "Progress dialog title (always shown, even for move - pre-existing limitation)"))
                .font(.headline)

            ProgressView(value: fraction)

            if isScanning {
                Text(String(localized: "progress.status.scanning", bundle: .module, comment: "Shown while pre-scanning the source tree, before totals are known"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(viewModel.currentFile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(
                    String(
                        format: NSLocalizedString(
                            "progress.status.fileCount",
                            bundle: .module,
                            comment: "Progress dialog: current file index of total. %1$d is the files processed so far, %2$d is the total file count."
                        ),
                        viewModel.filesProcessed, viewModel.totalFiles
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: viewModel.bytesTransferred, countStyle: .file))
                    Text(String(localized: "progress.label.of", bundle: .module, comment: "Separator between transferred and total byte counts, e.g. '10 MB of 100 MB'"))
                    Text(ByteCountFormatter.string(fromByteCount: viewModel.totalBytes, countStyle: .file))
                    Spacer()
                    Text(
                        String(
                            format: NSLocalizedString(
                                "progress.label.etaRemaining",
                                bundle: .module,
                                comment: "Estimated time remaining. %1$d is the number of seconds."
                            ),
                            Int(viewModel.eta)
                        )
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(String(localized: "progress.button.cancel", bundle: .module, comment: "Cancel button")) { viewModel.cancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}
