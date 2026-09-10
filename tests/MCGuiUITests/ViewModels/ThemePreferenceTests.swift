import Foundation
import SwiftUI
import Testing
@testable import MCGuiUI

/// Unit tests for `ThemePreference` (T46): the default value, persistence round-trip
/// through `@AppStorage` (via an injected `UserDefaults` suite, per the batch's own
/// guidance to avoid touching real system prefs), and the pure `colorScheme` mapping.
@Suite("ThemePreference")
@MainActor
struct ThemePreferenceTests {

    /// A fresh, empty `UserDefaults` suite isolated per test, so persistence tests never
    /// read/write real system preferences and never interfere with each other.
    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "ThemePreferenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - default value (TH-01)

    @Test("defaults to .system when nothing has been stored yet")
    func defaultsToSystem() {
        let defaults = makeTestDefaults()
        let storage = AppStorage(wrappedValue: ThemePreference.system, ThemePreference.storageKey, store: defaults)

        #expect(storage.wrappedValue == .system)
    }

    // MARK: - persistence round-trip (TH-06)

    @Test("a chosen preference persists across a new AppStorage instance reading the same store")
    func persistsAcrossRelaunch() {
        let defaults = makeTestDefaults()
        let storage = AppStorage(wrappedValue: ThemePreference.system, ThemePreference.storageKey, store: defaults)

        storage.wrappedValue = .dark

        let reloaded = AppStorage(wrappedValue: ThemePreference.system, ThemePreference.storageKey, store: defaults)
        #expect(reloaded.wrappedValue == .dark)
    }

    @Test("each preference round-trips through the same UserDefaults suite")
    func eachCaseRoundTrips() {
        let defaults = makeTestDefaults()

        for preference in ThemePreference.allCases {
            let storage = AppStorage(wrappedValue: ThemePreference.system, ThemePreference.storageKey, store: defaults)
            storage.wrappedValue = preference

            let reloaded = AppStorage(wrappedValue: ThemePreference.system, ThemePreference.storageKey, store: defaults)
            #expect(reloaded.wrappedValue == preference)
        }
    }

    // MARK: - colorScheme mapping (TH-02, TH-03, TH-04)

    @Test("colorScheme maps .system to nil (follow system appearance)")
    func systemMapsToNil() {
        #expect(ThemePreference.system.colorScheme == nil)
    }

    @Test("colorScheme maps .light to ColorScheme.light")
    func lightMapsToLightScheme() {
        #expect(ThemePreference.light.colorScheme == .light)
    }

    @Test("colorScheme maps .dark to ColorScheme.dark")
    func darkMapsToDarkScheme() {
        #expect(ThemePreference.dark.colorScheme == .dark)
    }

    // MARK: - rawValue round-trip (Codable/RawRepresentable for @AppStorage eligibility)

    @Test("every case round-trips through its rawValue")
    func rawValueRoundTrips() {
        for preference in ThemePreference.allCases {
            #expect(ThemePreference(rawValue: preference.rawValue) == preference)
        }
    }
}
