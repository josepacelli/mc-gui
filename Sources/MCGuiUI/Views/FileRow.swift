import SwiftUI
import MCGuiCore

@MainActor
public struct FileRow: View {
    public let entry: FileEntry
    public let isMarked: Bool

    public init(entry: FileEntry, isMarked: Bool = false) {
        self.entry = entry
        self.isMarked = isMarked
    }

    private var isBrokenSymlink: Bool {
        entry.isSymlink && entry.symlinkTarget == nil
    }

    public var body: some View {
        HStack {
            FileIcon(type: entry.type, isSymlinkBroken: isBrokenSymlink)
            Text(entry.name)
                .foregroundStyle(nameColor)
                .fontWeight(isMarked ? .bold : .regular)
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

    private var nameColor: AnyShapeStyle {
        if isBrokenSymlink { return AnyShapeStyle(.red) }
        if isMarked { return AnyShapeStyle(.orange) }
        return AnyShapeStyle(.primary)
    }

    private var sizeText: String {
        entry.type == .directory ? "" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
    }
}
