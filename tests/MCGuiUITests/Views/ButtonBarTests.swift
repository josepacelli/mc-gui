import Testing
@testable import MCGuiUI

/// Unit tests for `ButtonBar`'s pure static helpers (classic-layout-parity CL-03..CL-07).
/// `ButtonBar.body` is thin declarative glue over these, consistent with the project's
/// existing view-testing pattern (`PanelViewFileOperationsTests`).
@Suite("ButtonBar")
struct ButtonBarTests {

    @Test("labels match the original terminal mc's exact 10 button texts, in order (CL-04)")
    func labelsMatchOriginal() {
        let expected: [(Int, String)] = [
            (1, "Help"), (2, "Menu"), (3, "View"), (4, "Edit"), (5, "Copy"),
            (6, "RenMov"), (7, "Mkdir"), (8, "Delete"), (9, "PullDn"), (10, "Quit"),
        ]

        #expect(ButtonBar.labels.count == expected.count)
        for (actual, expectedPair) in zip(ButtonBar.labels, expected) {
            #expect(actual.number == expectedPair.0)
            #expect(actual.text == expectedPair.1)
        }
    }

    @Test("buttons 3-8 map to the matching PanelAction (CL-05)")
    func actionForNumberMapsPanelKeys() {
        #expect(ButtonBar.action(for: 3) == .view)
        #expect(ButtonBar.action(for: 4) == .edit)
        #expect(ButtonBar.action(for: 5) == .copy)
        #expect(ButtonBar.action(for: 6) == .move)
        #expect(ButtonBar.action(for: 7) == .mkdir)
        #expect(ButtonBar.action(for: 8) == .delete)
    }

    @Test("buttons 1, 2, 9, 10 have no PanelAction")
    func actionForNumberNilForUnimplementedAndQuit() {
        #expect(ButtonBar.action(for: 1) == nil)
        #expect(ButtonBar.action(for: 2) == nil)
        #expect(ButtonBar.action(for: 9) == nil)
        #expect(ButtonBar.action(for: 10) == nil)
    }

    @Test("buttons 1, 2, 9 are disabled; the rest are not (CL-07)")
    func isDisabledMatchesUnimplementedButtons() {
        for number in [1, 2, 9] {
            #expect(ButtonBar.isDisabled(number))
        }
        for number in [3, 4, 5, 6, 7, 8, 10] {
            #expect(!ButtonBar.isDisabled(number))
        }
    }
}
