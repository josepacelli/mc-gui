import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("MainWindowViewModel")
@MainActor
struct MainWindowViewModelTests {

    private func makeViewModel() -> MainWindowViewModel {
        let service = MockFileSystemService { _ in [] }
        return MainWindowViewModel(
            fileSystemService: service,
            leftInitialPath: URL(fileURLWithPath: "/tmp/left"),
            rightInitialPath: URL(fileURLWithPath: "/tmp/right")
        )
    }

    @Test("default active panel is left")
    func defaultActivePanelIsLeft() {
        let viewModel = makeViewModel()

        #expect(viewModel.activePanel == .left)
        #expect(viewModel.activePanelViewModel === viewModel.leftPanel)
    }

    @Test("activate(.right) makes the right panel active")
    func activateRightPanel() {
        let viewModel = makeViewModel()

        viewModel.activate(.right)

        #expect(viewModel.activePanel == .right)
        #expect(viewModel.activePanelViewModel === viewModel.rightPanel)
    }

    @Test("switchActivePanel toggles between left and right")
    func switchActivePanelToggles() {
        let viewModel = makeViewModel()

        viewModel.switchActivePanel()
        #expect(viewModel.activePanel == .right)

        viewModel.switchActivePanel()
        #expect(viewModel.activePanel == .left)
    }
}
