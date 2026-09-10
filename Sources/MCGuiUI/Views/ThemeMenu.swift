import SwiftUI

/// The View menu's Theme submenu (MB-04): Follow System / Light / Dark options (TH-02,
/// TH-03, TH-04), bound via `@AppStorage` to the same `ThemePreference.storageKey` every
/// other theme-aware view reads. Selecting an option here updates immediately everywhere
/// (TH-05) - no message-passing needed, since `@AppStorage` on the same key is a shared,
/// observed value across every view that declares it (here and in `MainWindow`).
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
