import SwiftUI

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
        HStack(spacing: 5) {
            ForEach(Self.labels, id: \.number) { label in
                FunctionKeyButton(
                    number: label.number,
                    title: label.text,
                    isDisabled: Self.isDisabled(label.number),
                    action: { handle(label.number) }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
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

    nonisolated static func isDisabled(_ number: Int) -> Bool {
        [9].contains(number)
    }
}

private struct FunctionKeyButton: View {
    let number: Int
    let title: String
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isDisabled ? Color.secondary : Color.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlColor).opacity(isHovered && !isDisabled ? 0.9 : 0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(isHovered && !isDisabled ? 0.18 : 0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.38 : 1)
        .onHover { isHovered = $0 }
    }
}
