import SwiftUI
import MCGuiCore

@MainActor
public struct FileRow: View {
    public let entry: FileEntry

    public init(entry: FileEntry) {
        self.entry = entry
    }

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
        .contentShape(Rectangle())
    }

    private var sizeText: String {
        entry.type == .directory ? "" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
    }
}
