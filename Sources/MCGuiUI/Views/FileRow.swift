import SwiftUI
import MCGuiCore

/// A single row in a panel's file list: icon, name, size, modification date, and
/// permissions for one `FileEntry`.
public struct FileRow: View {
    public let entry: FileEntry

    public init(entry: FileEntry) {
        self.entry = entry
    }

    /// A symlink whose target couldn't be resolved (`FileSystemServiceImpl` leaves
    /// `symlinkTarget` `nil` when it can't read the link) - rendered with a distinct
    /// visual per Edge Case 3.
    private var isBrokenSymlink: Bool {
        entry.isSymlink && entry.symlinkTarget == nil
    }

    public var body: some View {
        HStack {
            FileIcon(type: entry.type, isSymlinkBroken: isBrokenSymlink)
            Text(entry.name)
                .foregroundStyle(isBrokenSymlink ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                .italic(isBrokenSymlink)
            Spacer()
            Text(sizeText)
                .foregroundStyle(.secondary)
            Text(entry.modificationDate, style: .date)
                .foregroundStyle(.secondary)
            PermissionBadge(permissions: entry.permissions)
        }
    }

    private var sizeText: String {
        entry.type == .directory ? "" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
    }
}
