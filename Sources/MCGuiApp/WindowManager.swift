import AppKit
import SwiftUI
import MCGuiCore
import MCGuiUI
import MCGuiMacOS

@MainActor
public final class WindowManager {
    private var mainWindow: NSWindow?
    private var mainViewModel: MainWindowViewModel?
    private var viewerWindows: [NSWindow] = []
    private var editorWindows: [NSWindow] = []
    private var progressWindows: [NSWindow] = []
    private var userMenuWindows: [NSWindow] = []
    private var helpWindow: NSWindow?
    private var helpWindowCloseObserver: WindowCloseObserver?

    public init() {}

    public func showMainWindow(
        viewModel: MainWindowViewModel,
        onViewFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in },
        onEditFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in },
        bookmarksViewModel: BookmarksViewModel,
        userMenuViewModel: UserMenuViewModel
    ) {
        mainViewModel = viewModel

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        let content = MainWindow(
            viewModel: viewModel,
            onViewFile: onViewFile,
            onEditFile: onEditFile,
            onShowProgress: { [weak self] progressViewModel in self?.showProgress(progressViewModel) },
            onShowHelp: { [weak self] in self?.showHelp() },
            onShowUserMenu: { [weak self] context in self?.showUserMenu(viewModel: userMenuViewModel, context: context) },
            bookmarksViewModel: bookmarksViewModel
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = "Midnight Commander"
        window.setContentSize(NSSize(width: 1024, height: 640))
        let autosaveName = "MainWindow"
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(autosaveName)
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    public func showViewer(for entry: FileEntry, panel: PanelSide) {
        let panelEntries = panel == .left ? mainViewModel?.leftPanel.entries : mainViewModel?.rightPanel.entries
        let service = ViewerServiceImpl()
        service.setFileList((panelEntries ?? []).map(\.path))
        let viewModel = ViewerViewModel(viewerService: service)

        var window: NSWindow!
        let content = ViewerWindow(viewModel: viewModel, initialURL: entry.path, onClose: { [weak self] in
            self?.closeWindow(window, from: \.viewerWindows)
        })
        window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = entry.name
        window.setContentSize(NSSize(width: 800, height: 600))
        centerOverMainWindow(window)
        window.makeKeyAndOrderFront(nil)
        viewerWindows.append(window)
    }

    public func showEditor(for entry: FileEntry) {
        Task {
            let service = EditorServiceImpl()
            do {
                let document = try await service.open(entry.path)
                let viewModel = EditorWindowViewModel(editorService: service, document: document)

                var window: NSWindow!
                let content = EditorWindow(viewModel: viewModel, onClosed: { [weak self] in
                    self?.closeWindow(window, from: \.editorWindows)
                })
                window = NSWindow(contentViewController: NSHostingController(rootView: content))
                window.title = entry.name
                window.setContentSize(NSSize(width: 800, height: 600))
                centerOverMainWindow(window)
                window.makeKeyAndOrderFront(nil)
                editorWindows.append(window)
            } catch {
                let alert = NSAlert()
                alert.messageText = String(
                    format: NSLocalizedString("windowManager.alert.couldNotOpen", bundle: .module, comment: "Alert title when opening a file in the editor fails. %1$@ is the file name."),
                    entry.name
                )
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    public func showDialog<Content: View>(content: Content) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.makeKeyAndOrderFront(nil)
    }

    public func showProgress(_ progressViewModel: ProgressDialogViewModel) {
        let content = ProgressDialog(viewModel: progressViewModel)
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = String(localized: "windowManager.title.copying", bundle: .module, comment: "Progress window title shown while a copy/move runs")
        window.styleMask = [.titled, .closable]
        centerOverMainWindow(window)
        window.makeKeyAndOrderFront(nil)
        progressWindows.append(window)

        let minimumDisplayDuration: TimeInterval = 0.5
        let openedAt = Date()
        Task { [weak self] in
            while !progressViewModel.isCompleted {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            let remaining = minimumDisplayDuration - Date().timeIntervalSince(openedAt)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            self?.closeWindow(window, from: \.progressWindows)
        }
    }

    public func showHelp() {
        if let helpWindow {
            helpWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(contentViewController: NSHostingController(rootView: HelpWindow()))
        window.title = String(localized: "windowManager.title.help", bundle: .module, comment: "F1 Help window title")
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 480, height: 520))
        let observer = WindowCloseObserver { [weak self] in self?.helpWindow = nil }
        window.delegate = observer
        helpWindowCloseObserver = observer
        centerOverMainWindow(window)
        window.makeKeyAndOrderFront(nil)
        helpWindow = window
    }

    public func showUserMenu(viewModel: UserMenuViewModel, context: UserMenuContext) {
        let content = UserMenuView(viewModel: viewModel, context: context)
            .frame(minWidth: 420, minHeight: 320)
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = String(localized: "windowManager.title.userMenu", bundle: .module, comment: "F2 User Menu window title")
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 460, height: 360))
        centerOverMainWindow(window)
        window.makeKeyAndOrderFront(nil)
        userMenuWindows.append(window)
    }

    public func bringViewerToFront() {
        viewerWindows.last?.makeKeyAndOrderFront(nil)
    }

    public func bringEditorToFront() {
        editorWindows.last?.makeKeyAndOrderFront(nil)
    }

    private func closeWindow(_ window: NSWindow, from keyPath: ReferenceWritableKeyPath<WindowManager, [NSWindow]>) {
        self[keyPath: keyPath].removeAll { $0 === window }
        window.close()
    }

    private func centerOverMainWindow(_ window: NSWindow) {
        guard let mainWindow else {
            window.center()
            return
        }
        let mainFrame = mainWindow.frame
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: mainFrame.midX - size.width / 2,
            y: mainFrame.midY - size.height / 2
        ))
    }
}

private final class WindowCloseObserver: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
