import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("ConflictDialogViewModel")
@MainActor
struct ConflictDialogViewModelTests {

    private let destination = URL(fileURLWithPath: "/tmp/dest/a.txt")


    @Test("chooseOverwrite records .overwrite and reports it via onResolve")
    func chooseOverwriteResolvesOverwrite() {
        var reported: FileConflictResolution?
        let viewModel = ConflictDialogViewModel(destinationPath: destination) { reported = $0 }

        viewModel.chooseOverwrite()

        #expect(viewModel.resolution == .overwrite)
        #expect(reported == .overwrite)
    }

    @Test("chooseSkip records .skip and reports it via onResolve")
    func chooseSkipResolvesSkip() {
        var reported: FileConflictResolution?
        let viewModel = ConflictDialogViewModel(destinationPath: destination) { reported = $0 }

        viewModel.chooseSkip()

        #expect(viewModel.resolution == .skip)
        #expect(reported == .skip)
    }

    @Test("chooseRename records .rename and reports it via onResolve")
    func chooseRenameResolvesRename() {
        var reported: FileConflictResolution?
        let viewModel = ConflictDialogViewModel(destinationPath: destination) { reported = $0 }

        viewModel.chooseRename()

        #expect(viewModel.resolution == .rename)
        #expect(reported == .rename)
    }

    @Test("chooseCancel records .cancel and reports it via onResolve")
    func chooseCancelResolvesCancel() {
        var reported: FileConflictResolution?
        let viewModel = ConflictDialogViewModel(destinationPath: destination) { reported = $0 }

        viewModel.chooseCancel()

        #expect(viewModel.resolution == .cancel)
        #expect(reported == .cancel)
    }


    @Test("destinationPath exposes the conflicting file's URL")
    func destinationPathIsExposed() {
        let viewModel = ConflictDialogViewModel(destinationPath: destination)

        #expect(viewModel.destinationPath == destination)
    }
}
