import SwiftUI

/// F1's help window: a static reference page (app name + a shortcuts table). Scoped down
/// from the original mc's sidebar-topic-tree/full-text-search/contextual-per-widget help
/// system (help-system-f1/spec.md) to a single scrollable page - real, useful reference
/// info without that much larger undertaking.
@MainActor
public struct HelpWindow: View {
    private struct Shortcut {
        let keys: String
        let action: String
    }

    // MARK: - localized labels (I18N-01..04). Keyboard glyphs (F2, ⌘D, *, ...) are never
    // translated - only the action description text. "Midnight Commander" (the app name,
    // below) is likewise never translated per spec.md's confirmed assumption.

    private static var subtitle: String { String(localized: "help.subtitle", bundle: .module, comment: "Help window subtitle under the app name") }
    private static var panelShortcutsTitle: String { String(localized: "help.section.panelShortcuts", bundle: .module, comment: "Help window: Panel Shortcuts section title") }
    private static var globalShortcutsTitle: String { String(localized: "help.section.globalShortcuts", bundle: .module, comment: "Help window: Global Shortcuts section title") }
    private static var parentDirectoryAction: String { String(localized: "help.action.parentDirectory", bundle: .module, comment: "Help window: 'navigate to parent directory' action description, shared by the panel and global shortcut lists") }

    private static var panelShortcuts: [Shortcut] {
        [
            Shortcut(keys: "F2", action: String(localized: "help.panel.userMenu", bundle: .module, comment: "Help window: F2 action description")),
            Shortcut(keys: "F3", action: String(localized: "help.panel.viewFile", bundle: .module, comment: "Help window: F3 action description")),
            Shortcut(keys: "F4", action: String(localized: "help.panel.editFile", bundle: .module, comment: "Help window: F4 action description")),
            Shortcut(keys: "F5", action: String(localized: "help.panel.copy", bundle: .module, comment: "Help window: F5 action description")),
            Shortcut(keys: "F6", action: String(localized: "help.panel.moveRename", bundle: .module, comment: "Help window: F6 action description")),
            Shortcut(keys: "F7", action: String(localized: "help.panel.newFolder", bundle: .module, comment: "Help window: F7 action description")),
            Shortcut(keys: "F8", action: String(localized: "help.panel.delete", bundle: .module, comment: "Help window: F8 action description")),
            Shortcut(keys: "Enter", action: String(localized: "help.panel.openEntry", bundle: .module, comment: "Help window: Enter action description")),
            Shortcut(keys: "Backspace", action: parentDirectoryAction),
            Shortcut(keys: "Tab", action: String(localized: "help.panel.switchPanel", bundle: .module, comment: "Help window: Tab action description")),
            Shortcut(keys: "Space", action: String(localized: "help.panel.toggleSelection", bundle: .module, comment: "Help window: Space action description")),
            Shortcut(keys: "Insert", action: String(localized: "help.panel.toggleSelectionMoveDown", bundle: .module, comment: "Help window: Insert action description")),
            Shortcut(keys: "*", action: String(localized: "help.panel.invertSelection", bundle: .module, comment: "Help window: * action description")),
            Shortcut(keys: "Escape", action: String(localized: "help.panel.closeOrClear", bundle: .module, comment: "Help window: Escape action description")),
            Shortcut(keys: "⌘←  /  ⌘→", action: String(localized: "help.panel.jumpFirstLast", bundle: .module, comment: "Help window: Cmd+Left/Right action description")),
        ]
    }

    private static var globalShortcuts: [Shortcut] {
        [
            Shortcut(keys: "⌘1 – ⌘4", action: String(localized: "help.global.sortShortcuts", bundle: .module, comment: "Help window: Cmd+1..4 action description")),
            Shortcut(keys: "⌘.", action: String(localized: "help.global.toggleHiddenFiles", bundle: .module, comment: "Help window: Cmd+. action description")),
            Shortcut(keys: "⌘↑", action: parentDirectoryAction),
            Shortcut(keys: "⌘[  /  ⌘]", action: String(localized: "help.global.backForward", bundle: .module, comment: "Help window: Cmd+[/] action description")),
            Shortcut(keys: "⌘D", action: String(localized: "help.global.addBookmark", bundle: .module, comment: "Help window: Cmd+D action description")),
            Shortcut(keys: "⌘F", action: String(localized: "help.global.find", bundle: .module, comment: "Help window: Cmd+F action description")),
            Shortcut(keys: "⌘Q", action: String(localized: "help.global.quit", bundle: .module, comment: "Help window: Cmd+Q action description")),
        ]
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Midnight Commander").font(.largeTitle.bold())
                    Text(Self.subtitle).foregroundStyle(.secondary)
                }

                shortcutSection(title: Self.panelShortcutsTitle, shortcuts: Self.panelShortcuts)
                shortcutSection(title: Self.globalShortcutsTitle, shortcuts: Self.globalShortcuts)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func shortcutSection(title: String, shortcuts: [Shortcut]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(shortcuts.indices, id: \.self) { index in
                HStack {
                    Text(shortcuts[index].keys)
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 110, alignment: .leading)
                    Text(shortcuts[index].action)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
