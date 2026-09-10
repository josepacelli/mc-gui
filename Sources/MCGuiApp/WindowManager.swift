import AppKit
import SwiftUI
import MCGuiCore
import MCGuiUI
import MCGuiMacOS

/// Manages the app's windows: the single main window, and per-file viewer/editor windows
/// (T49). This is the cross-target bridge `MCGuiUI`'s `ViewerWindow`/`EditorWindow` (T38,
/// T43) explicitly could not build themselves: only `MCGuiApp` can import both `MCGuiUI`
/// (the windows/views) and `MCGuiMacOS` (the concrete `ViewerServiceImpl`/
/// `EditorServiceImpl` those windows need to actually load a file).
///
/// Windows are plain `NSWindow`s hosting a SwiftUI root view via `NSHostingController`,
/// not SwiftUI `Scene`s - `AppEntry` (T50) uses a single `Settings` scene for the app's
/// required `Scene` conformance and creates/shows every real window imperatively through
/// this type instead, matching design.md's `WindowManager` interface.
@MainActor
public final class WindowManager {
    private var mainWindow: NSWindow?
    private var mainViewModel: MainWindowViewModel?
    private var viewerWindows: [NSWindow] = []
    private var editorWindows: [NSWindow] = []
    private var progressWindows: [NSWindow] = []
    private var userMenuWindows: [NSWindow] = []
    // F1: a singleton, unlike the arrays above - reopening Help should refocus the one
    // that's already there, not accumulate duplicates. `helpWindowCloseObserver` keeps
    // the delegate (see `WindowCloseObserver` below) alive for as long as the window is
    // open - `NSWindow.delegate` is weak, so nothing else would.
    private var helpWindow: NSWindow?
    private var helpWindowCloseObserver: WindowCloseObserver?

    public init() {}

    /// Shows the single main window (MB-01, FS-01), creating it on first call and simply
    /// re-activating it on any later call. `onViewFile`/`onEditFile` close the F3/F4 gap
    /// `ViewerWindow`/`EditorWindow` (T38, T43) left open: they're forwarded straight into
    /// `MainWindow`, which forwards them into each `PanelView` (T50).
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
        window.center()
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    /// Opens a viewer window for `entry` (F3, FV-01), constructing a fresh
    /// `ViewerServiceImpl` and supplying it `panel`'s current file list via
    /// `setFileList(_:)` so Tab/Shift+Tab navigation (FV-05) works.
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
        window.makeKeyAndOrderFront(nil)
        viewerWindows.append(window)
    }

    /// Opens an editor window for `entry` (F4, ED-01). Loading is async (a fresh
    /// `EditorServiceImpl.open(_:)` call), since `EditorWindowViewModel` needs an
    /// already-loaded `EditorDocumentState` to construct. On a load failure, shows a
    /// simple alert rather than opening a broken editor - spec.md defines no specific
    /// "editor failed to open" UX, so this is the minimal honest fallback.
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
                window.makeKeyAndOrderFront(nil)
                editorWindows.append(window)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Could Not Open \(entry.name)"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    /// Presents arbitrary SwiftUI `content` as its own window - a general-purpose escape
    /// hatch for a dialog that needs a real window rather than a `.sheet` attached to an
    /// existing one, per design.md's `WindowManager` interface.
    public func showDialog<Content: View>(content: Content) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.makeKeyAndOrderFront(nil)
    }

    /// FO-14: presents a copy/move's progress as an independent, non-modal window (per
    /// user request - it used to be a `.sheet` blocking the whole main window until the
    /// operation finished). Closes itself once `progressViewModel.isCompleted` (success or
    /// cancellation both end the underlying `AsyncStream`, so both reach this the same way).
    public func showProgress(_ progressViewModel: ProgressDialogViewModel) {
        let content = ProgressDialog(viewModel: progressViewModel)
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = "Copying…"
        window.styleMask = [.titled, .closable]
        window.makeKeyAndOrderFront(nil)
        progressWindows.append(window)

        // Bugfix: `.onChange(of: progressViewModel.isCompleted)` attached to `content`
        // never reliably fired here - nothing else about this window's view tree ever
        // re-renders once the dialog's own fields stop changing, so the completion flip
        // went undetected and the window was left open forever ("terminou mas não fechou
        // a janela"). Polling the @MainActor view model directly (this `Task` inherits
        // `WindowManager`'s MainActor isolation, so the read is safe) sidesteps SwiftUI's
        // diffing entirely.
        //
        // Also (separately): a fast copy/move (a handful of small local files) could
        // finish before AppKit ever drew the just-opened window, making it look like
        // progress was never shown at all. Keeping the window up for at least
        // `minimumDisplayDuration` after it opens guarantees the user sees it.
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

    /// F1: shows the (singleton) Help window, creating it on first call and refocusing it
    /// on any later call - unlike `showViewer`/`showEditor`/`showUserMenu`, there's only
    /// ever one, and it has no per-call context to make a fresh window meaningful.
    public func showHelp() {
        if let helpWindow {
            helpWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(contentViewController: NSHostingController(rootView: HelpWindow()))
        window.title = "Help"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 480, height: 520))
        let observer = WindowCloseObserver { [weak self] in self?.helpWindow = nil }
        window.delegate = observer
        helpWindowCloseObserver = observer
        window.makeKeyAndOrderFront(nil)
        helpWindow = window
    }

    /// F2: opens a fresh User Menu window bound to `viewModel` (the app-lifetime instance
    /// `AppDelegate` owns, so item add/remove persists across separate F2 presses) and
    /// `context` (that specific press's active-panel state) - unlike Help, always a new
    /// window, since a stale open one would show the wrong %f/%d/%D context.
    public func showUserMenu(viewModel: UserMenuViewModel, context: UserMenuContext) {
        let content = UserMenuView(viewModel: viewModel, context: context)
            .frame(minWidth: 420, minHeight: 320)
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = "User Menu"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 460, height: 360))
        window.makeKeyAndOrderFront(nil)
        userMenuWindows.append(window)
    }

    /// Brings the most recently opened viewer window to the front (Window menu > Viewer,
    /// MB-06). A no-op when no viewer is open.
    public func bringViewerToFront() {
        viewerWindows.last?.makeKeyAndOrderFront(nil)
    }

    /// Brings the most recently opened editor window to the front (Window menu > Editor,
    /// MB-06). A no-op when no editor is open.
    public func bringEditorToFront() {
        editorWindows.last?.makeKeyAndOrderFront(nil)
    }

    private func closeWindow(_ window: NSWindow, from keyPath: ReferenceWritableKeyPath<WindowManager, [NSWindow]>) {
        self[keyPath: keyPath].removeAll { $0 === window }
        window.close()
    }
}

/// Runs `onClose` when its window closes for *any* reason, including the native red
/// close-button (unlike `ViewerWindow`/`EditorWindow`'s `onClose`/`onClosed` closures,
/// which only fire from a keypress inside their own SwiftUI content). Used for
/// `WindowManager.showHelp`'s singleton tracking, where a stale reference to an
/// already-closed window would silently break re-showing it on the next F1 press.
private final class WindowCloseObserver: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
