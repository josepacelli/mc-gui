import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("MkdirDialogViewModel")
@MainActor
struct MkdirDialogViewModelTests {

    // MARK: - valid name (FO-11)

    @Test("valid name creates the directory at parentDirectory/name and completes")
    func validNameCreatesDirectory() async {
        final class Recorder { var createdURL: URL? }
        let recorder = Recorder()
        let service = MockFileSystemService(createDirectoryImpl: { url in recorder.createdURL = url })
        let viewModel = MkdirDialogViewModel(fileSystemService: service, parentDirectory: URL(fileURLWithPath: "/tmp"))
        viewModel.name = "NewFolder"

        await viewModel.confirm()

        #expect(recorder.createdURL == URL(fileURLWithPath: "/tmp/NewFolder"))
        #expect(viewModel.isCompleted)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - empty name (FO-10)

    @Test("empty name is rejected with an error message and no directory is created")
    func emptyNameIsRejected() async {
        final class Recorder { var callCount = 0 }
        let recorder = Recorder()
        let service = MockFileSystemService(createDirectoryImpl: { _ in recorder.callCount += 1 })
        let viewModel = MkdirDialogViewModel(fileSystemService: service, parentDirectory: URL(fileURLWithPath: "/tmp"))
        viewModel.name = ""

        await viewModel.confirm()

        #expect(viewModel.errorMessage == MkdirValidationError.empty.errorDescription)
        #expect(viewModel.isCompleted == false)
        #expect(recorder.callCount == 0)
    }

    // MARK: - name containing "/" (FO-10)

    @Test("name containing a path separator is rejected with an error message and no directory is created")
    func nameWithSlashIsRejected() async {
        final class Recorder { var callCount = 0 }
        let recorder = Recorder()
        let service = MockFileSystemService(createDirectoryImpl: { _ in recorder.callCount += 1 })
        let viewModel = MkdirDialogViewModel(fileSystemService: service, parentDirectory: URL(fileURLWithPath: "/tmp"))
        viewModel.name = "sub/folder"

        await viewModel.confirm()

        #expect(viewModel.errorMessage == MkdirValidationError.containsPathSeparator.errorDescription)
        #expect(viewModel.isCompleted == false)
        #expect(recorder.callCount == 0)
    }

    // MARK: - filesystem failure surfaces as errorMessage

    @Test("a filesystem failure on a valid name surfaces its reason and does not complete")
    func filesystemFailureSurfacesErrorMessage() async {
        let service = MockFileSystemService(createDirectoryImpl: { _ in throw MockError(message: "Already exists") })
        let viewModel = MkdirDialogViewModel(fileSystemService: service, parentDirectory: URL(fileURLWithPath: "/tmp"))
        viewModel.name = "Existing"

        await viewModel.confirm()

        #expect(viewModel.errorMessage == "Already exists")
        #expect(viewModel.isCompleted == false)
    }
}
