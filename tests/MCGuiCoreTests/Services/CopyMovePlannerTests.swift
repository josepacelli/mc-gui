import Foundation
import Testing
@testable import MCGuiCore

@Suite("CopyMovePlanner")
struct CopyMovePlannerTests {

    private func entry(named name: String) -> FileEntry {
        FileEntry(
            name: name,
            path: URL(fileURLWithPath: "/tmp/\(name)"),
            size: 0,
            creationDate: Date(timeIntervalSince1970: 0),
            modificationDate: Date(timeIntervalSince1970: 0),
            permissions: [.ownerRead],
            type: .file,
            isHidden: false,
            isSymlink: false,
            symlinkTarget: nil
        )
    }


    @Test("conflicts returns an empty array when no source name exists at the destination")
    func noConflictDetected() {
        let sources = [entry(named: "a.txt"), entry(named: "b.txt")]
        let destination = [entry(named: "c.txt")]

        let result = CopyMovePlanner.conflicts(for: sources, in: destination)

        #expect(result == [])
    }

    @Test("conflicts returns the single source whose name already exists at the destination")
    func singleConflictDetected() {
        let clashing = entry(named: "a.txt")
        let sources = [clashing, entry(named: "b.txt")]
        let destination = [entry(named: "a.txt")]

        let result = CopyMovePlanner.conflicts(for: sources, in: destination)

        #expect(result == [clashing])
    }

    @Test("conflicts returns every source whose name already exists at the destination")
    func multiConflictDetected() {
        let first = entry(named: "a.txt")
        let second = entry(named: "b.txt")
        let sources = [first, second, entry(named: "c.txt")]
        let destination = [entry(named: "a.txt"), entry(named: "b.txt")]

        let result = CopyMovePlanner.conflicts(for: sources, in: destination)

        #expect(result == [first, second])
    }


    @Test("resolvedName suggests ' (1)' before the extension when there is no existing name")
    func resolvedNameFirstSuffix() {
        let result = CopyMovePlanner.resolvedName(for: "file.txt", existingNames: [])

        #expect(result == "file (1).txt")
    }

    @Test("resolvedName skips suffixes that already exist and returns the next free one")
    func resolvedNameSkipsExistingSuffixes() {
        let result = CopyMovePlanner.resolvedName(
            for: "file.txt",
            existingNames: ["file (1).txt", "file (2).txt"]
        )

        #expect(result == "file (3).txt")
    }

    @Test("resolvedName handles a name with no extension")
    func resolvedNameWithoutExtension() {
        let result = CopyMovePlanner.resolvedName(for: "file", existingNames: [])

        #expect(result == "file (1)")
    }

    @Test("resolvedName returns nil when every suffix up to maxAttempts is already taken")
    func resolvedNameExhaustedSuffixSearch() {
        let existingNames: Set<String> = ["file (1).txt", "file (2).txt", "file (3).txt"]

        let result = CopyMovePlanner.resolvedName(for: "file.txt", existingNames: existingNames, maxAttempts: 3)

        #expect(result == nil)
    }
}
