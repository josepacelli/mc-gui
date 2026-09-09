import Foundation
import Testing
@testable import MCGuiCore

@Suite("EditorDocumentState, ViewerState, ViewerContent, FileConflictResolution")
struct EditorViewerStateTests {

    @Test("EditorDocumentState round-trips through Codable")
    func editorDocumentStateCodableRoundTrip() throws {
        let original = EditorDocumentState(
            content: "hello world",
            fileURL: URL(fileURLWithPath: "/tmp/note.txt"),
            isDirty: true,
            encoding: "utf-8"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditorDocumentState.self, from: data)

        #expect(decoded == original)
    }

    @Test(
        "each ViewerContent case round-trips through Codable",
        arguments: [
            ViewerContent.text("line 1\nline 2"),
            ViewerContent.image(Data([0xFF, 0xD8, 0xFF])),
            ViewerContent.hexData(Data([0x00, 0x01, 0x02]))
        ]
    )
    func viewerContentCases(content: ViewerContent) throws {
        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(ViewerContent.self, from: data)

        #expect(decoded == content)
    }

    @Test("ViewerState holds mode, content, scrollPosition, and searchQuery")
    func viewerStateHoldsFields() {
        let state = ViewerState(
            mode: .hex,
            content: .hexData(Data([0x10])),
            scrollPosition: 42.5,
            searchQuery: "needle"
        )

        #expect(state.mode == .hex)
        #expect(state.content == .hexData(Data([0x10])))
        #expect(state.scrollPosition == 42.5)
        #expect(state.searchQuery == "needle")
    }

    @Test(
        "each FileConflictResolution case round-trips to its raw string value",
        arguments: [
            (FileConflictResolution.overwrite, "overwrite"),
            (FileConflictResolution.skip, "skip"),
            (FileConflictResolution.rename, "rename"),
            (FileConflictResolution.cancel, "cancel")
        ]
    )
    func fileConflictResolutionCases(resolution: FileConflictResolution, rawValue: String) throws {
        #expect(resolution.rawValue == rawValue)

        let data = try JSONEncoder().encode(resolution)
        let decoded = try JSONDecoder().decode(FileConflictResolution.self, from: data)
        #expect(decoded == resolution)
    }
}
