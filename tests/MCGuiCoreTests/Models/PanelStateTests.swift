import Foundation
import Testing
@testable import MCGuiCore

@Suite("PanelState, PanelSortColumn, PanelPathHistory")
struct PanelStateTests {

    @Test("PanelPathHistory round-trips through Codable")
    func panelPathHistoryCodableRoundTrip() throws {
        let original = PanelPathHistory(
            past: [URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")],
            future: [URL(fileURLWithPath: "/tmp/c")]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PanelPathHistory.self, from: data)

        #expect(decoded == original)
        #expect(decoded.past == original.past)
        #expect(decoded.future == original.future)
    }

    @Test("default PanelState is empty with expected defaults")
    func panelStateDefaultEmptyState() {
        let path = URL(fileURLWithPath: "/Users/example")
        let state = PanelState(currentPath: path)

        #expect(state.currentPath == path)
        #expect(state.entries.isEmpty)
        #expect(state.selectedIndices.isEmpty)
        #expect(state.sortColumn == .name)
        #expect(state.sortAscending == true)
        #expect(state.showHidden == false)
        #expect(state.history == PanelPathHistory(past: [], future: []))
    }

    @Test("populated PanelState holds all provided fields")
    func panelStatePopulatedState() {
        let path = URL(fileURLWithPath: "/Users/example/docs")
        let entry = FileEntry(
            name: "readme.md",
            path: path.appendingPathComponent("readme.md"),
            size: 10,
            creationDate: Date(timeIntervalSince1970: 0),
            modificationDate: Date(timeIntervalSince1970: 0),
            permissions: [.ownerRead],
            type: .file,
            isHidden: false,
            isSymlink: false,
            symlinkTarget: nil
        )
        let history = PanelPathHistory(past: [URL(fileURLWithPath: "/Users")], future: [])

        let state = PanelState(
            currentPath: path,
            entries: [entry],
            selectedIndices: [0],
            sortColumn: .size,
            sortAscending: false,
            showHidden: true,
            history: history
        )

        #expect(state.currentPath == path)
        #expect(state.entries == [entry])
        #expect(state.selectedIndices == [0])
        #expect(state.sortColumn == .size)
        #expect(state.sortAscending == false)
        #expect(state.showHidden == true)
        #expect(state.history == history)
    }
}
