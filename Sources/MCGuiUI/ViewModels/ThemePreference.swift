import SwiftUI

/// The user's System/Light/Dark theme choice (TH-01..TH-04).
///
/// Conforms to `RawRepresentable` with a `String` raw value, which lets it be used
/// directly as an `@AppStorage`-backed value (`@AppStorage(ThemePreference.storageKey) var
/// preference: ThemePreference = .system`) - SwiftUI's `AppStorage` has a built-in overload
/// for any `RawRepresentable where RawValue == String`, so no separate persistence wrapper
/// class is needed (TH-06). Declaring `@AppStorage` directly on each consuming `View`
/// (`ThemeMenu`, T47; `MainWindow`, T47) is what makes theme changes propagate live
/// (TH-05): every view reading the same key re-renders automatically when it changes,
/// since `AppStorage` is a `DynamicProperty` SwiftUI observes.
public enum ThemePreference: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    /// The `UserDefaults` key `@AppStorage` uses to persist this preference (TH-06).
    public static let storageKey = "themePreference"

    /// The `ColorScheme` `.preferredColorScheme(_:)` should apply for this preference
    /// (TH-02, TH-03, TH-04). `nil` for `.system`, meaning "follow the system appearance"
    /// (TH-01) - `.preferredColorScheme(nil)` is exactly how SwiftUI expresses that.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
