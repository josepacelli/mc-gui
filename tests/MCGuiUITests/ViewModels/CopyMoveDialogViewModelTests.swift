import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("CopyMoveDialogViewModel")
@MainActor
struct CopyMoveDialogViewModelTests {

    private func defaultOptions() -> CopyMoveOptions {
        CopyMoveOptions(preserveAttributes: false, followSymlinks: true, updateOnly: false)
    }

    // MARK: - copy mode (FO-01)

    @Test("copy mode is held as-is")
    func copyModeIsHeld() {
        let viewModel = CopyMoveDialogViewModel(
            sources: [makeTestEntry(name: "a.txt")],
            destinationDirectory: URL(fileURLWithPath: "/tmp/dest"),
            mode: .copy,
            options: defaultOptions()
        )

        #expect(viewModel.mode == .copy)
    }

    // MARK: - move mode (FO-02)

    @Test("move mode is held as-is")
    func moveModeIsHeld() {
        let viewModel = CopyMoveDialogViewModel(
            sources: [makeTestEntry(name: "a.txt")],
            destinationDirectory: URL(fileURLWithPath: "/tmp/dest"),
            mode: .move,
            options: defaultOptions()
        )

        #expect(viewModel.mode == .move)
    }

    // MARK: - options toggling

    @Test("options can be read back after construction and after mutation")
    func optionsToggling() {
        let viewModel = CopyMoveDialogViewModel(
            sources: [makeTestEntry(name: "a.txt")],
            destinationDirectory: URL(fileURLWithPath: "/tmp/dest"),
            mode: .copy,
            options: CopyMoveOptions(preserveAttributes: false, followSymlinks: true, updateOnly: false)
        )

        #expect(viewModel.options.preserveAttributes == false)
        #expect(viewModel.options.followSymlinks == true)
        #expect(viewModel.options.updateOnly == false)

        viewModel.options.preserveAttributes = true
        viewModel.options.followSymlinks = false
        viewModel.options.updateOnly = true

        #expect(viewModel.options.preserveAttributes == true)
        #expect(viewModel.options.followSymlinks == false)
        #expect(viewModel.options.updateOnly == true)
    }

    // MARK: - delegates conflict resolution to ConflictDialogViewModel

    @Test("resolveConflict delegates to the injected ConflictDialogViewModel-backed resolver")
    func resolveConflictDelegatesToConflictDialogViewModel() async {
        let conflictViewModel = ConflictDialogViewModel(destinationPath: URL(fileURLWithPath: "/tmp/dest/a.txt"))
        let viewModel = CopyMoveDialogViewModel(
            sources: [makeTestEntry(name: "a.txt")],
            destinationDirectory: URL(fileURLWithPath: "/tmp/dest"),
            mode: .copy,
            options: defaultOptions(),
            resolveConflict: { _ in
                conflictViewModel.chooseOverwrite()
                return conflictViewModel.resolution ?? .cancel
            }
        )

        let resolution = await viewModel.resolveConflict(at: URL(fileURLWithPath: "/tmp/dest/a.txt"))

        #expect(resolution == .overwrite)
        #expect(conflictViewModel.resolution == .overwrite)
    }
}
