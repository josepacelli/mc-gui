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

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.name)
                .font(.headline)

            row(String(localized: "info.field.path", bundle: .module, comment: "Full path field label"), entry.path.path)
            row(String(localized: "info.field.kind", bundle: .module, comment: "Kind field label"), kindText)
            row(String(localized: "info.field.size", bundle: .module, comment: "Size field label"), sizeText)

            if entry.isSymlink, let target = entry.symlinkTarget {
                row(String(localized: "info.field.symlinkTarget", bundle: .module, comment: "Symlink target field label"), target.path)
            }

            HStack {
                Text(String(localized: "info.field.permissions", bundle: .module, comment: "Permissions field label"))
                    .foregroundStyle(.secondary)
                Spacer()
                PermissionBadge(permissions: entry.permissions)
            }

            HStack(alignment: .top) {
                Text(String(localized: "info.field.created", bundle: .module, comment: "Created date field label"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.creationDate, style: .date)
            }

            HStack(alignment: .top) {
                Text(String(localized: "info.field.modified", bundle: .module, comment: "Modified date field label"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.modificationDate, style: .date)
            }

            HStack {
                Spacer()
                Button(String(localized: "info.button.close", bundle: .module, comment: "Close button"), role: .cancel, action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 360)
        .task { await viewModel.startSizeCalculationIfNeeded() }
    }
}
