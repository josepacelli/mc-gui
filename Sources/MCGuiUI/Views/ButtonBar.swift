import SwiftUI

/// The classic bottom function-key button row (`classic-layout-parity` CL-03..CL-07),
/// reproducing the original terminal mc's `WButtonBar` (`lib/widget/buttonbar.c`):
/// 1 Help, 2 Menu, 3 View, 4 Edit, 5 Copy, 6 RenMov, 7 Mkdir, 8 Delete, 9 PullDn, 10 Quit.
///
/// Buttons 3-8 forward through `onAction`, which the caller (`MainWindow`) routes into
/// the active panel's `pendingAction` binding - the same path physical F3-F8 already use
/// inside `PanelView`. Button 10 calls `onQuit` directly. Buttons 1, 2, and 9 have no
/// backing implementation yet (SPEC_DEVIATION: F1 has no Help viewer, F2 has no user
/// menu, F9 has no programmatic way to open a SwiftUI `Menu` - matches STATE.md's
/// existing accepted Known Limitations for the same three keys), so they render
/// disabled instead of silently doing nothing on click (CL-07).
public struct ButtonBar: View {
    public var onAction: (PanelAction) -> Void
    public var onQuit: () -> Void

    public init(onAction: @escaping (PanelAction) -> Void, onQuit: @escaping () -> Void) {
        self.onAction = onAction
        self.onQuit = onQuit
    }

    /// The original's exact 10 labels, in order (CL-04).
    static let labels: [(number: Int, text: String)] = [
        (1, "Help"), (2, "Menu"), (3, "View"), (4, "Edit"), (5, "Copy"),
        (6, "RenMov"), (7, "Mkdir"), (8, "Delete"), (9, "PullDn"), (10, "Quit"),
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
        } else if number == 10 {
            onQuit()
        }
    }

    /// Maps a button number to the `PanelAction` it triggers (CL-05). `nil` for 1/2/9
    /// (no implementation, CL-07) and for 10 (Quit routes through `onQuit`, not a
    /// `PanelAction`, since it isn't panel-scoped).
    static func action(for number: Int) -> PanelAction? {
        switch number {
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
    static func isDisabled(_ number: Int) -> Bool {
        [1, 2, 9].contains(number)
    }
}
