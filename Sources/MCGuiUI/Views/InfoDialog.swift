import SwiftUI
import MCGuiCore

@MainActor
public struct InfoDialog: View {
    public let viewModel: InfoDialogViewModel
    public var onClose: () -> Void

    public init(viewModel: InfoDialogViewModel, onClose: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    private var entry: FileEntry { viewModel.entry }

    private var kindText: String {
        switch entry.type {
        case .directory:
            return String(localized: "info.kind.folder", bundle: .module, comment: "Info dialog kind value: folder")
        case .symlink:
            return String(localized: "info.kind.symlink", bundle: .module, comment: "Info dialog kind value: symbolic link")
        default:
            return String(localized: "info.kind.file", bundle: .module, comment: "Info dialog kind value: file")
        }
    }

    private var sizeText: String {
        guard let totalSize = viewModel.totalSize else {
            return String(localized: "info.size.calculating", bundle: .module, comment: "Shown while a folder's recursive size is still being calculated")
        }
        let formatted = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        guard let itemCount = viewModel.itemCount else { return formatted }
        return String(
            format: NSLocalizedString(
                "info.size.withItemCount",
                bundle: .module,
                comment: "Folder size with item count. %1$@ is the formatted size, %2$d is the item count."
            ),
            formatted, itemCount
        )
    }

    private func row(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                FileIcon(type: entry.type, isSymlinkBroken: entry.isSymlink && entry.symlinkTarget == nil)
                Text(entry.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            VStack(alignment: .leading, spacing: 8) {
                row(String(localized: "info.field.path", bundle: .module, comment: "Full path field label"), entry.path.path, monospaced: true)
                Divider()
                row(String(localized: "info.field.kind", bundle: .module, comment: "Kind field label"), kindText)
                Divider()
                row(String(localized: "info.field.size", bundle: .module, comment: "Size field label"), sizeText)

                if entry.isSymlink, let target = entry.symlinkTarget {
                    Divider()
                    row(String(localized: "info.field.symlinkTarget", bundle: .module, comment: "Symlink target field label"), target.path, monospaced: true)
                }

                Divider()
                HStack {
                    Text(String(localized: "info.field.permissions", bundle: .module, comment: "Permissions field label"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    PermissionBadge(permissions: entry.permissions)
                }

                Divider()
                HStack(alignment: .top) {
                    Text(String(localized: "info.field.created", bundle: .module, comment: "Created date field label"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.creationDate, style: .date)
                        .font(.callout)
                }

                Divider()
                HStack(alignment: .top) {
                    Text(String(localized: "info.field.modified", bundle: .module, comment: "Modified date field label"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.modificationDate, style: .date)
                        .font(.callout)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Spacer()
                Button(String(localized: "info.button.close", bundle: .module, comment: "Close button"), role: .cancel, action: onClose)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 400)
        .task { await viewModel.startSizeCalculationIfNeeded() }
    }
}
