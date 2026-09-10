import SwiftUI
import MCGuiCore

/// A system icon representing a file entry's type. Broken symlinks (target could not be
/// resolved) render in a distinct color, per Edge Case 3.
public struct FileIcon: View {
    public let type: FileType
    public let isSymlinkBroken: Bool

    public init(type: FileType, isSymlinkBroken: Bool = false) {
        self.type = type
        self.isSymlinkBroken = isSymlinkBroken
    }

    public var body: some View {
        Image(systemName: symbolName)
            .foregroundStyle(isSymlinkBroken ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
    }

    private var symbolName: String {
        switch type {
        case .directory: return "folder.fill"
        case .symlink: return "arrow.triangle.turn.up.right.diamond.fill"
        case .volume: return "externaldrive.fill"
        case .file, .unknown: return "doc.fill"
        }
    }
}

/// A compact `rwx` display of a `FileEntry`'s owner permission triad.
public struct PermissionBadge: View {
    public let permissions: FilePermissions

    public init(permissions: FilePermissions) {
        self.permissions = permissions
    }

    public var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
    }

    private var text: String {
        let r = permissions.contains(.ownerRead) ? "r" : "-"
        let w = permissions.contains(.ownerWrite) ? "w" : "-"
        let x = permissions.contains(.ownerExecute) ? "x" : "-"
        return r + w + x
    }
}

/// A panel column header showing its title and, when it's the active sort column, a
/// direction chevron (FS-09).
public struct SortIndicator: View {
    public let title: String
    public let column: PanelSortColumn
    public let activeColumn: PanelSortColumn
    public let ascending: Bool

    public init(title: String, column: PanelSortColumn, activeColumn: PanelSortColumn, ascending: Bool) {
        self.title = title
        self.column = column
        self.activeColumn = activeColumn
        self.ascending = ascending
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if column == activeColumn {
                Image(systemName: ascending ? "chevron.up" : "chevron.down")
                    .font(.caption2)
            }
        }
    }
}

/// A spinner with a message, shown over a panel while its directory listing loads (FS-07).
public struct LoadingOverlay: View {
    public let message: String

    public init(message: String? = nil) {
        self.message = message ?? String(localized: "supportComponents.loading.message", bundle: .module, comment: "Default overlay message shown while a directory listing loads")
    }

    public var body: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(message)
                .font(.caption)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Standardized presentation for a failed operation's error message (FS-08).
public struct ErrorAlert: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
