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

    public init() {}

    /// Shows the single main window (MB-01, FS-01), creating it on first call and simply
    /// re-activating it on any later call. `onViewFile`/`onEditFile` close the F3/F4 gap
    /// `ViewerWindow`/`EditorWindow` (T38, T43) left open: they're forwarded straight into
    /// `MainWindow`, which forwards them into each `PanelView` (T50).
    public func showMainWindow(
        viewModel: MainWindowViewModel,
        onViewFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in },
        onEditFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in }
    ) {
        mainViewModel = viewModel

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        let content = MainWindow(viewModel: viewModel, onViewFile: onViewFile, onEditFile: onEditFile)
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = "MCGui"
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
