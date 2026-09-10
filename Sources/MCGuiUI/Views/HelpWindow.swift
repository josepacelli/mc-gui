import SwiftUI

/// F1's help window: a static reference page (app name + a shortcuts table). Scoped down
/// from the original mc's sidebar-topic-tree/full-text-search/contextual-per-widget help
/// system (help-system-f1/spec.md) to a single scrollable page - real, useful reference
/// info without that much larger undertaking.
public struct HelpWindow: View {
    private struct Shortcut {
        let keys: String
        let action: String
    }

    private static let panelShortcuts: [Shortcut] = [
        Shortcut(keys: "F2", action: "User menu"),
        Shortcut(keys: "F3", action: "View file"),
        Shortcut(keys: "F4", action: "Edit file"),
        Shortcut(keys: "F5", action: "Copy"),
        Shortcut(keys: "F6", action: "Move / Rename"),
        Shortcut(keys: "F7", action: "New folder"),
        Shortcut(keys: "F8", action: "Delete"),
        Shortcut(keys: "Enter", action: "Open directory / file"),
        Shortcut(keys: "Backspace", action: "Parent directory"),
        Shortcut(keys: "Tab", action: "Switch panel"),
        Shortcut(keys: "Space", action: "Toggle selection"),
        Shortcut(keys: "Insert", action: "Toggle selection, move down"),
        Shortcut(keys: "*", action: "Invert selection (select/deselect all)"),
        Shortcut(keys: "Escape", action: "Close dialog / clear selection"),
        Shortcut(keys: "⌘←  /  ⌘→", action: "Jump to first / last row"),
    ]

    private static let globalShortcuts: [Shortcut] = [
        Shortcut(keys: "⌘1 – ⌘4", action: "Sort by name / size / date / type"),
        Shortcut(keys: "⌘.", action: "Toggle hidden files"),
        Shortcut(keys: "⌘↑", action: "Parent directory"),
        Shortcut(keys: "⌘[  /  ⌘]", action: "Back / Forward"),
        Shortcut(keys: "⌘D", action: "Add bookmark"),
        Shortcut(keys: "⌘F", action: "Find (viewer / editor)"),
        Shortcut(keys: "⌘Q", action: "Quit"),
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Midnight Commander").font(.largeTitle.bold())
                    Text("A dual-pane file manager for macOS.").foregroundStyle(.secondary)
                }

                shortcutSection(title: "Panel Shortcuts", shortcuts: Self.panelShortcuts)
                shortcutSection(title: "Global Shortcuts", shortcuts: Self.globalShortcuts)
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
