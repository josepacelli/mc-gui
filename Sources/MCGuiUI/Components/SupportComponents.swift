import SwiftUI
import MCGuiCore

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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
