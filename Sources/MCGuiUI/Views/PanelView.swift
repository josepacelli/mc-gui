import SwiftUI
import AppKit
import MCGuiCore

/// A single file panel: renders `PanelViewModel.entries`, shows loading/error overlays,
/// and tracks focus so the active panel can be visually distinguished.
///
/// This is a focus-state skeleton only - full keyboard navigation (arrows, Tab, Space,
/// Insert) is wired in Phase 9 (`PanelCommands`/`KeyboardShortcuts`). The context menu
/// below is a stub; its actions are wired in a future task. F5/F6/F7/F8 file operations
/// (copy, move, mkdir, delete) are wired here (T33).
public struct PanelView: View {
    public let viewModel: PanelViewModel
    public let isActive: Bool
    public var onActivate: () -> Void
    // WindowManager gap closure (T50): F3/F4 need to construct and present a real
    // ViewerWindow/EditorWindow backed by a concrete ViewerServiceImpl/EditorServiceImpl
    // (MCGuiMacOS), which PanelView (MCGuiUI) cannot reach directly - MCGuiUI does not
    // depend on MCGuiMacOS. These closures let the caller (MainWindow -> WindowManager,
    // MCGuiApp) supply that behavior, mirroring `onActivate`'s existing pattern.
    public var onViewFile: (FileEntry) -> Void
    public var onEditFile: (FileEntry) -> Void

    @FocusState private var isFocused: Bool
    @State private var selection: Set<UUID> = []

    @State private var copyMoveViewModel: CopyMoveDialogViewModel?
    @State private var mkdirViewModel: MkdirDialogViewModel?
    @State private var deleteViewModel: DeleteConfirmDialogViewModel?
    @State private var operationErrorMessage: String?

    public init(
        viewModel: PanelViewModel,
        isActive: Bool,
        onActivate: @escaping () -> Void = {},
        onViewFile: @escaping (FileEntry) -> Void = { _ in },
        onEditFile: @escaping (FileEntry) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.isActive = isActive
        self.onActivate = onActivate
        self.onViewFile = onViewFile
        self.onEditFile = onEditFile
    }

    // MARK: - F-key handling (FV-01, ED-01, FO-01, FO-02, FO-10, FO-12)

    // NSF3FunctionKey..NSF8FunctionKey are AppKit's Unicode private-use-area scalars for
    // the physical F3-F8 keys; SwiftUI's `KeyEquivalent` has no dedicated function-key
    // constants, so this is the standard technique for binding to them via `.onKeyPress`.
    private static let f3Key = KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!))
    private static let f4Key = KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!))
    private static let f5Key = KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))
    private static let f6Key = KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))
    private static let f7Key = KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))
    private static let f8Key = KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))

    private var fileSystemService: FileSystemService { viewModel.fileSystemService }

    private var selectedEntries: [FileEntry] {
        viewModel.entries.filter { selection.contains($0.id) }
    }

    private var displayedErrorMessage: String? {
        operationErrorMessage ?? viewModel.errorMessage
    }

    public var body: some View {
        ZStack {
            List(viewModel.entries, selection: $selection) { entry in
                FileRow(entry: entry)
                    .contextMenu {
                        Text(entry.name)
                    }
            }
            .focusable()
            .focused($isFocused)
            .onChange(of: isFocused) { _, focused in
                if focused { onActivate() }
            }
            .onTapGesture { onActivate() }
            .onKeyPress(keys: [Self.f3Key, Self.f4Key, Self.f5Key, Self.f6Key, Self.f7Key, Self.f8Key]) { press in
                handleFunctionKey(press.key)
                return .handled
            }

            if viewModel.isLoading {
                LoadingOverlay()
            }

            if let displayedErrorMessage {
                ErrorAlert(message: displayedErrorMessage)
            }
        }
        .border(isActive ? Color.accentColor : Color.clear, width: 2)
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: presented($copyMoveViewModel)) {
            if let copyMoveViewModel {
                CopyMoveDialog(
                    viewModel: copyMoveViewModel,
                    onConfirm: { Task { await performCopyMove(copyMoveViewModel) } },
                    onCancel: { self.copyMoveViewModel = nil }
                )
            }
        }
        .sheet(isPresented: presented($mkdirViewModel)) {
            if let mkdirViewModel {
                MkdirDialog(viewModel: mkdirViewModel, onCancel: { self.mkdirViewModel = nil })
            }
        }
        .sheet(isPresented: presented($deleteViewModel)) {
            if let deleteViewModel {
                DeleteConfirmDialog(viewModel: deleteViewModel, onCancel: { self.deleteViewModel = nil })
            }
        }
        .onChange(of: mkdirViewModel?.isCompleted) { _, completed in
            guard completed == true else { return }
            mkdirViewModel = nil
            Task { await viewModel.load() }
        }
        .onChange(of: deleteViewModel?.isCompleted) { _, completed in
            guard completed == true else { return }
            deleteViewModel = nil
            selection = []
            Task { await viewModel.load() }
        }
    }

    private func presented<T>(_ binding: Binding<T?>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue != nil }, set: { if !$0 { binding.wrappedValue = nil } })
    }

    private func handleFunctionKey(_ key: KeyEquivalent) {
        switch key.character {
        case Self.f3Key.character: beginView()
        case Self.f4Key.character: beginEdit()
        case Self.f5Key.character: beginCopyOrMove(.copy)
        case Self.f6Key.character: beginCopyOrMove(.move)
        case Self.f7Key.character: beginMkdir()
        case Self.f8Key.character: beginDelete()
        default: break
        }
    }

    /// F3: opens the viewer on the first selected entry (FV-01). A no-op with nothing
    /// selected.
    private func beginView() {
        guard let entry = Self.targetEntry(selection: selectedEntries) else { return }
        onViewFile(entry)
    }

    /// F4: opens the editor on the first selected entry (ED-01). A no-op with nothing
    /// selected.
    private func beginEdit() {
        guard let entry = Self.targetEntry(selection: selectedEntries) else { return }
        onEditFile(entry)
    }

    private func beginCopyOrMove(_ mode: OperationMode) {
        operationErrorMessage = nil
        // SPEC_DEVIATION (T33): destination defaults to this panel's own current
        // directory, not the "other panel" (the classic dual-pane default) - PanelView
        // has no reference to its sibling panel without MainWindow wiring, which is out
        // of scope for this task (touches only PanelView.swift). The destination is
        // editable in CopyMoveDialog's text field before confirming.
        copyMoveViewModel = Self.makeCopyMoveDialog(
            selection: selectedEntries,
            mode: mode,
            destinationDirectory: viewModel.currentPath
        )
    }

    private func beginMkdir() {
        operationErrorMessage = nil
        mkdirViewModel = Self.makeMkdirDialog(fileSystemService: fileSystemService, parentDirectory: viewModel.currentPath)
    }

    private func beginDelete() {
        operationErrorMessage = nil
        deleteViewModel = Self.makeDeleteDialog(
            selection: selectedEntries,
            trashService: FileSystemTrashAdapter(fileSystemService: fileSystemService)
        )
    }

    private func performCopyMove(_ dialogViewModel: CopyMoveDialogViewModel) async {
        copyMoveViewModel = nil
        let plan = CopyMovePlan(
            sources: dialogViewModel.sources,
            destinationDirectory: dialogViewModel.destinationDirectory,
            mode: dialogViewModel.mode,
            options: dialogViewModel.options
        )
        do {
            let result = dialogViewModel.mode == .copy
                ? try await fileSystemService.copy(plan)
                : try await fileSystemService.move(plan)
            operationErrorMessage = Self.fo15Message(from: result)
        } catch {
            operationErrorMessage = error.localizedDescription
        }
        await viewModel.load()
    }

    // MARK: - Pure helpers (unit-tested; the body above is thin declarative glue)

    /// The entry F3/F4 should act on (FV-01, ED-01): the first selected entry, or `nil`
    /// when nothing is selected - F3/F4 with an empty selection is a no-op, mirroring
    /// F5/F6/F8's existing empty-selection precedent above.
    static func targetEntry(selection: [FileEntry]) -> FileEntry? {
        selection.first
    }

    /// Builds the F5/F6 copy/move dialog's ViewModel for `selection` (FO-01, FO-02).
    /// `nil` when there is nothing selected - F5/F6 with an empty selection is a no-op.
    static func makeCopyMoveDialog(
        selection: [FileEntry],
        mode: OperationMode,
        destinationDirectory: URL
    ) -> CopyMoveDialogViewModel? {
        guard !selection.isEmpty else { return nil }
        return CopyMoveDialogViewModel(
            sources: selection,
            destinationDirectory: destinationDirectory,
            mode: mode,
            options: CopyMoveOptions(preserveAttributes: true, followSymlinks: true, updateOnly: false)
        )
    }

    /// Builds the F7 new-folder dialog's ViewModel (FO-10). Unlike copy/move/delete,
    /// mkdir has no selection precondition.
    static func makeMkdirDialog(fileSystemService: FileSystemService, parentDirectory: URL) -> MkdirDialogViewModel {
        MkdirDialogViewModel(fileSystemService: fileSystemService, parentDirectory: parentDirectory)
    }

    /// Builds the F8 delete-confirmation dialog's ViewModel for `selection` (FO-12).
    /// `nil` when there is nothing selected - F8 with an empty selection is a no-op.
    static func makeDeleteDialog(selection: [FileEntry], trashService: TrashService) -> DeleteConfirmDialogViewModel? {
        guard !selection.isEmpty else { return nil }
        return DeleteConfirmDialogViewModel(trashService: trashService, entries: selection)
    }

    /// Formats a failed copy/move `OperationResult` into the specific-file-and-reason
    /// message FO-15 requires. `nil` when the operation succeeded.
    static func fo15Message(from result: OperationResult) -> String? {
        guard !result.success, let firstFailure = result.failedItems.first else { return nil }
        if result.failedItems.count == 1 {
            return "\(firstFailure.path): \(firstFailure.reason)"
        }
        return "\(firstFailure.path): \(firstFailure.reason) (+\(result.failedItems.count - 1) more)"
    }
}

/// Adapts `FileSystemService`'s own `trash(_:)` (already part of that protocol) to the
/// separate `TrashService` protocol `DeleteConfirmDialogViewModel` expects, so `PanelView`
/// doesn't need a second injected service to wire F8 (FO-12).
private struct FileSystemTrashAdapter: TrashService {
    let fileSystemService: FileSystemService

    func trash(_ urls: [URL]) async throws -> OperationResult {
        try await fileSystemService.trash(urls)
    }
}
