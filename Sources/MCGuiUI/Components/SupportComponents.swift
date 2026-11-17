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
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(iconColor)
            .frame(width: 18, alignment: .center)
    }

    private var iconColor: Color {
        if isSymlinkBroken { return .red }
        switch type {
        case .directory: return Color(nsColor: .systemBlue)
        case .symlink: return .teal
        case .volume: return .indigo
        case .file, .unknown: return .secondary
        }
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
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .frame(width: 40, alignment: .center)
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
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
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
                .font(.title3)
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
    }
}
