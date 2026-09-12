import Foundation
import Testing
@testable import MCGuiUI

@Suite("DraggedFileURLs")
struct DraggedFileURLsTests {

    @Test("encoding then decoding preserves sourcePanelID and paths")
    func roundTripsThroughJSON() throws {
        let id = UUID()
        let original = DraggedFileURLs(sourcePanelID: id, paths: [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt")
        ])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DraggedFileURLs.self, from: data)

        #expect(decoded.sourcePanelID == id)
        #expect(decoded.paths == original.paths)
    }

    @Test("round-trips an empty paths array")
    func roundTripsEmptyPaths() throws {
        let original = DraggedFileURLs(sourcePanelID: UUID(), paths: [])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DraggedFileURLs.self, from: data)

        #expect(decoded.paths.isEmpty)
    }
}
