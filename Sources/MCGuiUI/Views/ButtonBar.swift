import SwiftUI

/// The classic bottom function-key button row (`classic-layout-parity` CL-03..CL-07),
/// reproducing the original terminal mc's `WButtonBar` (`lib/widget/buttonbar.c`):
/// 1 Help, 2 Menu, 3 View, 4 Edit, 5 Copy, 6 RenMov, 7 Mkdir, 8 Delete, 9 PullDn, 10 Quit.
///
/// Buttons 2-8 forward through `onAction`, which the caller (`MainWindow`) routes into
/// the active panel's `pendingAction` binding - the same path physical F2-F8 already use
/// inside `PanelView` (button 2 maps to `PanelAction.userMenu`). Button 1 calls `onHelp`
/// directly (not a `PanelAction` - it needs no panel context). Button 10 calls `onQuit`
/// directly. Button 9 still has no backing implementation (SPEC_DEVIATION: no
/// programmatic way to open a SwiftUI `Menu` to pull down the `TopBar` - matches
/// STATE.md's accepted Known Limitation for this one key), so it renders disabled.
@MainActor
public struct ButtonBar: View {
    public var onAction: (PanelAction) -> Void
    public var onHelp: () -> Void
    public var onQuit: () -> Void

    public init(onAction: @escaping (PanelAction) -> Void, onHelp: @escaping () -> Void = {}, onQuit: @escaping () -> Void) {
        self.onAction = onAction
        self.onHelp = onHelp
        self.onQuit = onQuit
    }

    /// The original's exact 10 labels, in order (CL-04), localized (I18N-01..04).
    static let labels: [(number: Int, text: String)] = [
        (1, String(localized: "buttonBar.label.help", bundle: .module, comment: "F1 button: Help")),
        (2, String(localized: "buttonBar.label.menu", bundle: .module, comment: "F2 button: User Menu")),
        (3, String(localized: "buttonBar.label.view", bundle: .module, comment: "F3 button: View")),
        (4, String(localized: "buttonBar.label.edit", bundle: .module, comment: "F4 button: Edit")),
        (5, String(localized: "buttonBar.label.copy", bundle: .module, comment: "F5 button: Copy")),
        (6, String(localized: "buttonBar.label.renMov", bundle: .module, comment: "F6 button: Rename/Move")),
        (7, String(localized: "buttonBar.label.mkdir", bundle: .module, comment: "F7 button: New Folder")),
        (8, String(localized: "buttonBar.label.delete", bundle: .module, comment: "F8 button: Delete")),
        (9, String(localized: "buttonBar.label.pullDn", bundle: .module, comment: "F9 button: Pull Down (disabled, no backing implementation)")),
        (10, String(localized: "buttonBar.label.quit", bundle: .module, comment: "F10 button: Quit")),
    ]

    public var body: some View {
        HStack(spacing: 1) {
            ForEach(Self.labels, id: \.number) { label in
                Button {
                    handle(label.number)
                } label: {
                    HStack(spacing: 2) {
                        Text("\(label.number)").font(.caption2.bold())
                        Text(label.text).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(Self.isDisabled(label.number))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func handle(_ number: Int) {
        if let action = Self.action(for: number) {
            onAction(action)
        } else if number == 1 {
            onHelp()
        } else if number == 10 {
            onQuit()
        }
    }

    /// Maps a button number to the `PanelAction` it triggers (CL-05). `nil` for 1 (Help
    /// routes through `onHelp`, not a `PanelAction`, since it isn't panel-scoped), 9 (no
    /// implementation, CL-07), and 10 (Quit routes through `onQuit`).
    nonisolated static func action(for number: Int) -> PanelAction? {
        switch number {
        case 2: return .userMenu
        case 3: return .view
        case 4: return .edit
        case 5: return .copy
        case 6: return .move
        case 7: return .mkdir
        case 8: return .delete
        default: return nil
        }
    }

    /// Buttons with no backing implementation (CL-07).
    nonisolated static func isDisabled(_ number: Int) -> Bool {
        [9].contains(number)
    }
}
