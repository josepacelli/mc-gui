import Foundation
import Testing

@Suite("Localization key-set coverage (I18N-09)")
struct LocalizationCoverageTests {

    private static let targets = ["MCGuiUI", "MCGuiApp", "MCGuiMacOS"]
    private static let languages = ["pt-BR", "pt-PT", "es"]

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
