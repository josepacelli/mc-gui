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

    private var isParentEntry: Bool {
        entry.name == ".."
    }

    public var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isMarked ? Color.orange : Color.clear)
                .frame(width: 3, height: 14)

            if isParentEntry {
                Image(systemName: "arrow.uturn.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .center)
            } else {
                FileIcon(type: entry.type, isSymlinkBroken: isBrokenSymlink)
            }

            Text(entry.name)
                .font(.system(size: 12.5, weight: isMarked ? .semibold : .regular))
                .foregroundStyle(nameColor)
                .italic(isBrokenSymlink)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Text(sizeText)
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 68, alignment: .trailing)

            Text(dateText)
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 118, alignment: .trailing)

            if isParentEntry {
                Color.clear
                    .frame(width: 40, height: 16)
            } else {
                PermissionBadge(permissions: entry.permissions)
            }
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }

    private var nameColor: AnyShapeStyle {
        if isBrokenSymlink { return AnyShapeStyle(.red) }
        if isMarked { return AnyShapeStyle(.orange) }
        if isParentEntry { return AnyShapeStyle(.secondary) }
        return AnyShapeStyle(.primary)
    }

    private var sizeText: String {
        entry.type == .directory ? "" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
    }

    private var dateText: String {
        isParentEntry ? "" : entry.modificationDate.formatted(date: .numeric, time: .shortened)
    }
}
