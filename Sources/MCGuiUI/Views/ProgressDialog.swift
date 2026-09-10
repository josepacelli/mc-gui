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

    // Before the first source file/byte lands, `totalFiles == 0` means the operation is
    // still walking the source tree to compute real totals (`FileSystemServiceImpl.
    // expandedFiles`) - for a large folder that scan itself can take a few seconds, and
    // with nothing else on screen changing yet it looked like the dialog had frozen.
    private var isScanning: Bool {
        !viewModel.isCompleted && viewModel.totalFiles == 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // SPEC_DEVIATION: ProgressDialogViewModel has no copy-vs-move mode of its own
            // (pre-existing, not part of this localization task) - the header always reads
            // "Copying…" even during a move. Localizing the literal as-is; adding a mode
            // flag would be a behavior change outside T12's string-extraction scope.
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
