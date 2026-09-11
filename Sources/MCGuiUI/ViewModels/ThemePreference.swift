import SwiftUI

public enum ThemePreference: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    public static let storageKey = "themePreference"

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
