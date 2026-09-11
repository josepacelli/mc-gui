import Foundation
import Testing
@testable import MCGuiCore

@Suite("FileEntry, FileType, FilePermissions")
struct FileEntryTests {

    private func makeEntry(
        isHidden: Bool = false,
        isSymlink: Bool = false,
        symlinkTarget: URL? = nil,
        type: FileType = .file
    ) -> FileEntry {
        FileEntry(
            name: "example.txt",
            path: URL(fileURLWithPath: "/tmp/example.txt"),
            size: 42,
            creationDate: Date(timeIntervalSince1970: 0),
            modificationDate: Date(timeIntervalSince1970: 100),
            permissions: [.ownerRead, .ownerWrite],
            type: type,
            isHidden: isHidden,
            isSymlink: isSymlink,
            symlinkTarget: symlinkTarget
        )
    }

    @Test("FilePermissions round-trips through Codable")
    func filePermissionsCodableRoundTrip() throws {
        let original: FilePermissions = [.ownerRead, .ownerWrite, .otherExecute]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FilePermissions.self, from: data)

        #expect(decoded == original)
        #expect(decoded.contains(.ownerRead))
        #expect(decoded.contains(.ownerWrite))
        #expect(decoded.contains(.otherExecute))
        #expect(!decoded.contains(.groupRead))
    }

    @Test("symlink target is present when the entry is a symlink")
    func symlinkTargetPresent() {
        let target = URL(fileURLWithPath: "/tmp/real-file.txt")
        let entry = makeEntry(isSymlink: true, symlinkTarget: target, type: .symlink)

        #expect(entry.isSymlink)
        #expect(entry.symlinkTarget == target)
    }

    @Test("symlink target is absent when the entry is not a symlink")
    func symlinkTargetAbsent() {
        let entry = makeEntry(isSymlink: false, symlinkTarget: nil)

        #expect(!entry.isSymlink)
        #expect(entry.symlinkTarget == nil)
    }

    @Test("hidden flag reflects dotfile state", arguments: [true, false])
    func hiddenFlag(isHidden: Bool) {
        let entry = makeEntry(isHidden: isHidden)

        #expect(entry.isHidden == isHidden)
    }

    @Test(
        "each FileType case round-trips to its raw string value",
        arguments: [
            (FileType.file, "file"),
            (FileType.directory, "directory"),
            (FileType.symlink, "symlink"),
            (FileType.volume, "volume"),
            (FileType.unknown, "unknown")
        ]
    )
    func fileTypeCases(type: FileType, rawValue: String) {
        #expect(type.rawValue == rawValue)

        let entry = makeEntry(type: type)
        #expect(entry.type == type)
    }
}
