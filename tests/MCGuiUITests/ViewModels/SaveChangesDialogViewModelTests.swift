import Foundation
import Testing
@testable import MCGuiUI

@Suite("SaveChangesDialogViewModel")
@MainActor
struct SaveChangesDialogViewModelTests {


    @Test("chooseSave records .save and reports it via onResolve")
    func chooseSaveResolvesSave() {
        var reported: SaveChangesResult?
        let viewModel = SaveChangesDialogViewModel(fileName: "doc.txt") { reported = $0 }

        viewModel.chooseSave()

        #expect(viewModel.result == .save)
        #expect(reported == .save)
    }

    @Test("chooseDiscard records .discard and reports it via onResolve")
    func chooseDiscardResolvesDiscard() {
        var reported: SaveChangesResult?
        let viewModel = SaveChangesDialogViewModel(fileName: "doc.txt") { reported = $0 }

        viewModel.chooseDiscard()

        #expect(viewModel.result == .discard)
        #expect(reported == .discard)
    }

    @Test("chooseCancel records .cancel and reports it via onResolve")
    func chooseCancelResolvesCancel() {
        var reported: SaveChangesResult?
        let viewModel = SaveChangesDialogViewModel(fileName: "doc.txt") { reported = $0 }

        viewModel.chooseCancel()

        #expect(viewModel.result == .cancel)
        #expect(reported == .cancel)
    }


    @Test("message includes the file name being prompted about")
    func messageIncludesFileName() {
        let viewModel = SaveChangesDialogViewModel(fileName: "notes.txt")

        #expect(viewModel.fileName == "notes.txt")
        #expect(viewModel.message.contains("notes.txt"))
    }
}
