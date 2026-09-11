import SwiftUI

@MainActor
public struct ThemeMenu: View {
    @AppStorage(ThemePreference.storageKey) private var preference: ThemePreference = .system

    public init() {}

    public var body: some View {
        Button(label(for: .system)) { preference = .system }
        Button(label(for: .light)) { preference = .light }
        Button(label(for: .dark)) { preference = .dark }
    }

    private func label(for option: ThemePreference) -> String {
        let title = Self.title(for: option)
        return preference == option ? "✓ \(title)" : title
    }

    static func title(for option: ThemePreference) -> String {
        switch option {
        case .system: return String(localized: "themeMenu.option.system", bundle: .module, comment: "Theme menu: follow the macOS system appearance")
        case .light: return String(localized: "themeMenu.option.light", bundle: .module, comment: "Theme menu: always use the light appearance")
        case .dark: return String(localized: "themeMenu.option.dark", bundle: .module, comment: "Theme menu: always use the dark appearance")
        }
    }
}
