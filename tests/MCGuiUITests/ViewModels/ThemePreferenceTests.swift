import Foundation
import SwiftUI
import Testing
@testable import MCGuiUI

@Suite("ThemePreference")
@MainActor
struct ThemePreferenceTests {

    private func makeTestDefaults() -> UserDefaults {
        let suiteName = "ThemePreferenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }


    @Test("defaults to .system when nothing has been stored yet")
    func defaultsToSystem() {
        let defaults = makeTestDefaults()
        let storage = AppStorage(wrappedValue: ThemePreference.system, ThemePreference.storageKey, store: defaults)

        #expect(storage.wrappedValue == .system)
    }


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


    @Test("every case round-trips through its rawValue")
    func rawValueRoundTrips() {
        for preference in ThemePreference.allCases {
            #expect(ThemePreference(rawValue: preference.rawValue) == preference)
        }
    }
}
