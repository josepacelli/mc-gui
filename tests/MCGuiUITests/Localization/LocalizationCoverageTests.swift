import Foundation
import Testing

/// I18N-09: fails `swift test` when any target's pt-BR/pt-PT/es `Localizable.strings`
/// is missing a key present in that target's `en.lproj` (or has an extra/orphaned one).
/// A deterministic, CI-visible substitute for Xcode String Catalog's translation-state
/// UI, which classic `.strings` files (AD-005) don't have natively.
///
/// Reads the `.strings` source files directly (not the built `.bundle`s) via a path
/// relative to this test file's own location, so it works for all 3 targets
/// (`MCGuiUI`, `MCGuiApp`, `MCGuiMacOS`) without this test target needing to depend on
/// `MCGuiApp`/`MCGuiMacOS`.
@Suite("Localization key-set coverage (I18N-09)")
struct LocalizationCoverageTests {

    private static let targets = ["MCGuiUI", "MCGuiApp", "MCGuiMacOS"]
    private static let languages = ["pt-BR", "pt-PT", "es"]

    /// This file lives at `tests/MCGuiUITests/Localization/LocalizationCoverageTests.swift`;
    /// walk up 4 path components (file, Localization/, MCGuiUITests/, tests/) to reach
    /// the repo root.
    private static let repoRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    private static func lprojURL(target: String, language: String) -> URL {
        repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent(target)
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(language).lproj")
    }

    /// Parses a `.strings` file's key set: skips blank lines and comment lines starting
    /// with `//` or `/*`, splits each remaining line on `" = "`, strips the trailing
    /// `;` and surrounding quotes from the key.
    private static func keys(in lprojDirectory: URL) -> Set<String> {
        let file = lprojDirectory.appendingPathComponent("Localizable.strings")
        guard let contents = try? String(contentsOf: file, encoding: .utf8) else {
            return []
        }
        var result: Set<String> = []
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("//"), !line.hasPrefix("/*") else { continue }
            guard let separatorRange = line.range(of: " = ") else { continue }
            var key = String(line[line.startIndex..<separatorRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("\""), key.hasSuffix("\""), key.count >= 2 {
                key = String(key.dropFirst().dropLast())
            }
            result.insert(key)
        }
        return result
    }

    @Test(
        "a target's <language>.lproj key set exactly matches its en.lproj key set",
        arguments: targets, languages
    )
    func keySetMatchesEnglish(target: String, language: String) {
        let englishKeys = Self.keys(in: Self.lprojURL(target: target, language: "en"))
        let localizedKeys = Self.keys(in: Self.lprojURL(target: target, language: language))
        let missing = englishKeys.subtracting(localizedKeys)
        let orphaned = localizedKeys.subtracting(englishKeys)
        #expect(
            localizedKeys == englishKeys,
            "\(target)/\(language).lproj key set diverges from \(target)/en.lproj: missing \(missing), orphaned \(orphaned)"
        )
    }
}
