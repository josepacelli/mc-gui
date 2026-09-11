import Foundation
import Testing
@testable import MCGuiCore

@Suite("Package smoke test")
struct SmokeTests {
    @Test("MCGuiCore builds and its public models are usable from the test target")
    func packageBuildsAndCoreModelsAreUsable() {
        let entry = FileEntry(
            name: "smoke.txt",
            path: URL(fileURLWithPath: "/tmp/smoke.txt"),
            size: 7,
            creationDate: Date(timeIntervalSince1970: 0),
            modificationDate: Date(timeIntervalSince1970: 0),
            permissions: [.ownerRead, .ownerWrite],
            type: .file,
            isHidden: false,
            isSymlink: false,
            symlinkTarget: nil
        )

        #expect(entry.name == "smoke.txt")
        #expect(entry.type == .file)
        #expect(entry.permissions.contains(.ownerRead))
    }
}
