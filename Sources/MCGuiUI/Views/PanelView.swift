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
    // FO-14: copy/move progress used to be a `.sheet` (modal - blocked interacting with
    // this panel, effectively the whole window, until the operation finished). Per user
    // request ("faça a cópia async"), it's now presented as an independent, non-modal
    // window via this closure (mirrors `onViewFile`/`onEditFile` - `WindowManager`,
    // which can create a real standalone `NSWindow`, lives in `MCGuiApp`, unreachable
    // from here).
    public var onShowProgress: (ProgressDialogViewModel) -> Void
    // F1: opens the (context-free, singleton) Help window - mirrors `onViewFile`/
    // `onEditFile`/`onShowProgress`. Not a `PanelAction` since it needs no panel context.
    public var onHelp: () -> Void
    // F2: opens the User Menu with this panel's current context (%f/%d/%D) - routed
    // through `PanelAction.userMenu`/`perform` like F3-F8, see `beginUserMenu`.
    public var onUserMenu: (UserMenuContext) -> Void
    // classic-layout-parity CL-05: lets an outside caller (`MainWindow`, routing
    // `ButtonBar`/`TopBar` clicks for whichever panel is active) trigger the same F3-F8
    // handling physical key presses already run below - see `PanelAction`.
    public var pendingAction: Binding<PanelAction?>
    // FO-01, FO-02: the classic dual-pane copy/move default - F5/F6 offers the *other*
    // panel's current directory as the destination, not this panel's own. `MainWindow`
    // passes its sibling `PanelViewModel.currentPath` here, re-evaluated on every
    // `MainWindow.body` render so it always reflects the other panel's live location
    // (never this struct's own - `PanelView` has no reference to its sibling otherwise).
    // `nil` (the default) falls back to this panel's own path, matching the prior
    // behavior for callers/tests that don't wire a sibling.
    public var otherPanelPath: URL?
    // FO-14 bugfix: a copy/move's destination is often the *sibling* panel
    // (`otherPanelPath`), whose `PanelViewModel` this `PanelView` never holds a reference
    // to - `performCopyMove`'s own `viewModel.load()` only refreshes this panel's own
    // (source) listing. `MainWindow` wires this to reload the sibling `PanelViewModel`
    // directly, so its entries pick up whatever just landed in it.
    public var onOperationCompleted: () -> Void

    @FocusState private var isFocused: Bool
    @State private var selection: Set<UUID> = []
    // KN-05/KN-06: the row Space/Insert last acted on - see `currentRowID`.
    @State private var cursorID: FileEntry.ID?

    @State private var copyMoveViewModel: CopyMoveDialogViewModel?
    // FO-05..FO-09: the conflict dialog shown for each destination-name collision found
    // while resolving a copy/move, one at a time, before the operation actually runs.
    @State private var conflictDialogViewModel: ConflictDialogViewModel?
    @State private var mkdirViewModel: MkdirDialogViewModel?
    @State private var deleteViewModel: DeleteConfirmDialogViewModel?
    @State private var operationErrorMessage: String?
    // FO-14, FO-16: the actual running copy/move batch (post-conflict-resolution), so a
    // second F5/F6 press can't start a concurrent operation on the same panel, and so its
    // dialog's Cancel button (via `ProgressDialogViewModel.onCancel`) has something to
    // cancel.
    @State private var operationTask: Task<OperationResult, Error>?

    public init(
        viewModel: PanelViewModel,
        isActive: Bool,
        onActivate: @escaping () -> Void = {},
        onViewFile: @escaping (FileEntry) -> Void = { _ in },
        onEditFile: @escaping (FileEntry) -> Void = { _ in },
        onShowProgress: @escaping (ProgressDialogViewModel) -> Void = { _ in },
        onHelp: @escaping () -> Void = {},
        onUserMenu: @escaping (UserMenuContext) -> Void = { _ in },
        pendingAction: Binding<PanelAction?> = .constant(nil),
        otherPanelPath: URL? = nil,
        onOperationCompleted: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.isActive = isActive
        self.onActivate = onActivate
        self.onViewFile = onViewFile
        self.onEditFile = onEditFile
        self.onShowProgress = onShowProgress
        self.onHelp = onHelp
        self.onUserMenu = onUserMenu
        self.pendingAction = pendingAction
        self.otherPanelPath = otherPanelPath
        self.onOperationCompleted = onOperationCompleted
    }

    // MARK: - F-key handling (FV-01, ED-01, FO-01, FO-02, FO-10, FO-12)

    // NSF3FunctionKey..NSF8FunctionKey are AppKit's Unicode private-use-area scalars for
    // the physical F3-F8 keys; SwiftUI's `KeyEquivalent` has no dedicated function-key
    // constants, so this is the standard technique for binding to them via `.onKeyPress`.
    private static let f1Key = KeyEquivalent(Character(UnicodeScalar(NSF1FunctionKey)!))
    private static let f2Key = KeyEquivalent(Character(UnicodeScalar(NSF2FunctionKey)!))
    private static let f3Key = KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!))
    private static let f4Key = KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!))
    private static let f5Key = KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))
    private static let f6Key = KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))
    private static let f7Key = KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))
    private static let f8Key = KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))
    // KN-06: NSInsertFunctionKey is the same kind of AppKit private-use-area scalar as the
    // F-keys above - most Mac keyboards have no physical Insert key, but external/Windows
    // keyboards that do send this.
    private static let insertKey = KeyEquivalent(Character(UnicodeScalar(NSInsertFunctionKey)!))

    private var fileSystemService: FileSystemService { viewModel.fileSystemService }

    private var selectedEntries: [FileEntry] {
        viewModel.entries.filter { selection.contains($0.id) }
    }

    private var selectedDisplayEntries: [FileEntry] {
        displayEntries.filter { selection.contains($0.id) }
    }

    private var displayedErrorMessage: String? {
        operationErrorMessage ?? viewModel.errorMessage
    }

    /// The rows the `List` actually shows (FS-04, FS-05, KN-11): a synthetic ".." entry
    /// first (`nil` at the filesystem root, where there is no parent to go up to),
    /// followed by `viewModel.entries`. Kept separate from `viewModel.entries` itself so
    /// counts/selection/file-operation logic elsewhere (footer count, F5-F8) stay exactly
    /// as before - ".." is a display/navigation-only concept.
    private var displayEntries: [FileEntry] {
        if let parentEntry = Self.parentEntry(for: viewModel.currentPath) {
            return [parentEntry] + viewModel.entries
        }
        return viewModel.entries
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                entryList

                if viewModel.isLoading {
                    LoadingOverlay()
                }

                if let displayedErrorMessage {
                    ErrorAlert(message: displayedErrorMessage)
                }
            }

            footer
        }
        .border(isActive ? Color.accentColor : Color.clear, width: 2)
        .task {
            await viewModel.load()
        }
        .onChange(of: pendingAction.wrappedValue) { _, newValue in
            guard let newValue else { return }
            perform(newValue)
            pendingAction.wrappedValue = nil
        }
        .sheet(isPresented: presented($copyMoveViewModel)) {
            if let copyMoveViewModel {
                CopyMoveDialog(
                    viewModel: copyMoveViewModel,
                    onConfirm: { Task { await performCopyMove(copyMoveViewModel, background: false) } },
                    onConfirmBackground: { Task { await performCopyMove(copyMoveViewModel, background: true) } },
                    onCancel: { self.copyMoveViewModel = nil }
                )
            }
        }
        .sheet(isPresented: presented($conflictDialogViewModel)) {
            if let conflictDialogViewModel {
                ConflictDialog(viewModel: conflictDialogViewModel)
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

    // Split out of `body` (and its keyboard handling split across two `ViewModifier`s
    // below) because chaining every `.onKeyPress` directly in one expression made the
    // compiler give up with "unable to type-check this expression in reasonable time".
    private var entryList: some View {
        List(displayEntries, selection: $selection) { entry in
            FileRow(entry: entry)
                .contextMenu {
                    Text(entry.name)
                }
                // FS-04, KN-11: real `NSTableView.doubleAction`, not a SwiftUI gesture.
                // Two prior attempts both broke single-click selection to some degree:
                // `.onTapGesture(count: 2)`/`.simultaneousGesture(TapGesture(count: 2))`
                // made AppKit hold every click to see whether a second one follows before
                // committing the List's native selection (single-click became unreliable,
                // user-reported); detecting a double-click purely from `selection` changes
                // never fired at all, because clicking an *already*-selected row a second
                // time doesn't change `selection` (no `onChange` to observe). Installing
                // the table's own `doubleAction` runs independently of - and never delays -
                // its native single-click selection, because it's the same mechanism
                // AppKit itself uses to distinguish click counts.
                .background(TableDoubleClickInstaller(entries: displayEntries, onDoubleClick: activate))
        }
        .focusable()
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused { onActivate() }
        }
        .modifier(PanelPrimaryKeys(
            functionKeys: [Self.f1Key, Self.f2Key, Self.f3Key, Self.f4Key, Self.f5Key, Self.f6Key, Self.f7Key, Self.f8Key],
            onFunctionKey: handleFunctionKey,
            onReturn: activateSelected,
            onBackspace: navigateToParent
        ))
        .modifier(PanelSelectionKeys(
            insertKey: Self.insertKey,
            onJumpFirst: { jumpToEdge(first: true) },
            onJumpLast: { jumpToEdge(first: false) },
            onToggle: toggleCurrentSelection,
            onToggleAndAdvance: toggleAndAdvanceSelection,
            onSelectAll: selectAllEntries,
            onDeselectAll: deselectAllEntries,
            onInvertSelection: invertSelection,
            onEscape: handleEscape
        ))
    }

    // MARK: - Classic chrome (classic-layout-parity CL-09..CL-12): header shows the
    // current path, footer shows the entry count or, once something is selected, the
    // selected count - mirrors the original terminal panel's title/status-line border.

    private var header: some View {
        Text(viewModel.currentPath.path)
            .font(.system(.caption, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.head)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isActive ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.15))
    }

    private var footer: some View {
        HStack {
            if selection.isEmpty {
                Text("\(viewModel.entries.count) files")
            } else {
                Text("\(selection.count) of \(viewModel.entries.count) selected")
            }
            Spacer()
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.gray.opacity(0.1))
    }

    private func presented<T>(_ binding: Binding<T?>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue != nil }, set: { if !$0 { binding.wrappedValue = nil } })
    }

    private func handleFunctionKey(_ key: KeyEquivalent) {
        // F1 is not a PanelAction (it needs no panel context - see onHelp's doc comment).
        if key.character == Self.f1Key.character {
            onHelp()
            return
        }
        guard let action = Self.action(forKey: key) else { return }
        perform(action)
    }

    /// FS-04, KN-11: Enter navigates into the selected directory (or the ".." entry) /
    /// opens the selected file. Mirrors F3/F4's existing "first selected entry, no-op
    /// when empty" precedent. Returns whether there was a target to act on, so the caller
    /// can report the key press as `.ignored` rather than `.handled` when there wasn't.
    private func activateSelected() -> Bool {
        guard let entry = Self.targetEntry(selection: selectedDisplayEntries) else { return false }
        activate(entry)
        return true
    }

    /// Maps a physical F2-F8 key press to the `PanelAction` it triggers (F1 is handled
    /// separately in `handleFunctionKey` - it isn't a `PanelAction`).
    static func action(forKey key: KeyEquivalent) -> PanelAction? {
        switch key.character {
        case Self.f2Key.character: return .userMenu
        case Self.f3Key.character: return .view
        case Self.f4Key.character: return .edit
        case Self.f5Key.character: return .copy
        case Self.f6Key.character: return .move
        case Self.f7Key.character: return .mkdir
        case Self.f8Key.character: return .delete
        default: return nil
        }
    }

    /// Runs `action` through the same handlers physical F2-F8 already use (CL-05) -
    /// shared by `handleFunctionKey` and the `pendingAction` binding.
    private func perform(_ action: PanelAction) {
        switch action {
        case .view: beginView()
        case .edit: beginEdit()
        case .copy: beginCopyOrMove(.copy)
        case .move: beginCopyOrMove(.move)
        case .mkdir: beginMkdir()
        case .delete: beginDelete()
        case .userMenu: beginUserMenu()
        }
    }

    /// F2: opens the User Menu with this panel's current context - the first selected
    /// entry's path (`%f`, `nil` when nothing is selected - the command author decides
    /// whether that's fine), this panel's current directory (`%d`), and the other
    /// panel's (`%D`).
    private func beginUserMenu() {
        onUserMenu(UserMenuContext(
            currentFile: selectedEntries.first?.path,
            currentDir: viewModel.currentPath,
            otherDir: otherPanelPath ?? viewModel.currentPath
        ))
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
        // Progress is a non-modal window now, so - unlike before - the user really can
        // press F5/F6 again while one is still running on this panel; refuse rather than
        // race a second `operationTask` into the same @State slot.
        guard operationTask == nil else { return }
        operationErrorMessage = nil
        // FO-01, FO-02: defaults to the *other* panel's current directory (the classic
        // dual-pane default) via `otherPanelPath`, falling back to this panel's own path
        // when there is no sibling (e.g. a caller/test that doesn't wire one). Always
        // editable in CopyMoveDialog's text field before confirming either way.
        copyMoveViewModel = Self.makeCopyMoveDialog(
            selection: selectedEntries,
            mode: mode,
            destinationDirectory: otherPanelPath ?? viewModel.currentPath
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

    /// Runs `entry`'s double-click/Enter activation (FS-04, KN-11): navigates into a
    /// directory (the ".." entry included - it's just a `FileEntry` whose `path` is the
    /// parent), or opens a file in the viewer (F3's default, the safer of view/edit for
    /// an implicit "open" trigger the spec doesn't disambiguate further).
    private func activate(_ entry: FileEntry) {
        switch Self.activationResult(for: entry) {
        case .navigate(let target):
            Task { await viewModel.load(target) }
        case .view(let file):
            onViewFile(file)
        }
    }

    /// FS-05: Backspace navigates to the parent directory unconditionally (no selection
    /// precondition), mirroring `AppCommandActions.navigateToParent`.
    private func navigateToParent() {
        Task { await viewModel.load(viewModel.currentPath.deletingLastPathComponent()) }
    }

    /// KN-04: jumps the selection to the first/last row via `PanelCommands.jump`. A no-op
    /// on an empty panel.
    private func jumpToEdge(first: Bool) {
        guard let target = PanelCommands.jump(toFirst: first, entries: displayEntries) else { return }
        selection = [target]
    }

    /// KN-05: Space toggles the current row (`cursorID` when set, else the sole member of
    /// `selection`, else the first row) via `PanelCommands.toggleSelection`, and does not
    /// move afterward - `cursorID` is recorded so a following Insert (KN-06) resumes from
    /// the same row rather than losing track of it once `selection` holds several marks.
    /// A no-op on an empty panel.
    private func toggleCurrentSelection() {
        guard let currentID = currentRowID else { return }
        selection = PanelCommands.toggleSelection(selection, id: currentID, entries: displayEntries)
        cursorID = currentID
    }

    /// KN-06: Insert toggles the current row exactly like Space, then additionally
    /// advances `cursorID` to `PanelCommands.toggleAndAdvance`'s `nextCursor` - unlike
    /// KN-04/05's shared-handler predecessor, this actually calls the distinct
    /// `toggleAndAdvance` API so repeated Insert presses mark descending rows without an
    /// arrow key in between, independent of how many rows `selection` has already
    /// accumulated (which `selection.first` alone can't track once it's more than one).
    private func toggleAndAdvanceSelection() {
        guard let currentID = currentRowID else { return }
        let result = PanelCommands.toggleAndAdvance(selection, id: currentID, entries: displayEntries)
        selection = result.selection
        cursorID = result.nextCursor ?? currentID
    }

    /// The row Space/Insert act on: `cursorID` (set by the last Space/Insert) when
    /// present, else whichever single row is currently selected (arrow-key/click
    /// navigation), else the first row.
    private var currentRowID: FileEntry.ID? {
        cursorID ?? selection.first ?? displayEntries.first?.id
    }

    /// "*": selects every entry via `PanelCommands.selectAll`. Deliberately scoped to
    /// `viewModel.entries` (not `displayEntries`) so the synthetic ".." row is never
    /// selected by this - a batch operation over ".." would be meaningless.
    private func selectAllEntries() {
        selection = PanelCommands.selectAll(entries: viewModel.entries)
    }

    /// "-": clears the whole selection - a secondary key for keyboards with no working
    /// physical Delete key (per user report), and the natural opposite of "*"/select-all.
    private func deselectAllEntries() {
        selection = PanelCommands.deselectAll()
    }

    /// Cmd+I: inverts the whole selection - the classic mc "*" behavior, moved to its own
    /// key once "*" itself became select-all (per user request).
    private func invertSelection() {
        selection = PanelCommands.invertSelection(selection, entries: viewModel.entries)
    }

    /// KN-12, SF-04: runs whichever `escapeAction` applies to the current state. Progress
    /// is no longer part of this - it's a non-modal window now (`onShowProgress`), with
    /// its own Cancel button; Escape on the panel has nothing to dismiss for it anymore.
    private func handleEscape() {
        switch Self.escapeAction(hasOpenSheet: hasOpenSheet, filterText: viewModel.filterText, hasSelection: !selection.isEmpty) {
        case .dismissSheet:
            conflictDialogViewModel = nil
            copyMoveViewModel = nil
            mkdirViewModel = nil
            deleteViewModel = nil
        case .clearFilter:
            viewModel.clearFilter()
        case .clearSelection:
            selection = []
        case .none:
            break
        }
    }

    private var hasOpenSheet: Bool {
        conflictDialogViewModel != nil || copyMoveViewModel != nil || mkdirViewModel != nil || deleteViewModel != nil
    }

    /// FO-05..FO-09: resolves every destination-name conflict (one dialog at a time) before
    /// running the copy/move, then applies the batch with whatever the user chose per file.
    private func performCopyMove(_ dialogViewModel: CopyMoveDialogViewModel, background: Bool) async {
        copyMoveViewModel = nil
        operationErrorMessage = nil

        let destinationEntries = (try? await fileSystemService.listDirectory(dialogViewModel.destinationDirectory)) ?? []
        let conflicts = CopyMovePlanner.conflicts(for: dialogViewModel.sources, in: destinationEntries)

        var resolutions: [(FileEntry, FileConflictResolution)] = []
        for conflict in conflicts {
            let destinationPath = dialogViewModel.destinationDirectory.appendingPathComponent(conflict.name)
            let resolution = await resolveConflict(destinationPath: destinationPath)
            resolutions.append((conflict, resolution))
            if resolution == .cancel { break }
        }

        switch Self.applyResolutions(
            sources: dialogViewModel.sources,
            resolutions: resolutions,
            existingNames: Set(destinationEntries.map(\.name))
        ) {
        case .cancelled:
            return

        case .proceed(let sources, let renames):
            guard !sources.isEmpty else {
                await viewModel.load()
                return
            }

            let plan = CopyMovePlan(
                sources: sources,
                destinationDirectory: dialogViewModel.destinationDirectory,
                mode: dialogViewModel.mode,
                options: dialogViewModel.options,
                renames: renames
            )
            await runWithProgress(plan, mode: dialogViewModel.mode, background: background)
            await viewModel.load()
            onOperationCompleted()
        }
    }

    /// FO-14, FO-16: runs `plan` through `fileSystemService`'s progress-reporting
    /// copy/move. Per user request, progress is presented as an independent, non-modal
    /// window (`onShowProgress`) instead of a blocking sheet, so the rest of the app stays
    /// usable while it runs - its Cancel button wires to `operationTask.cancel()`, and
    /// `fileSystemService.copy`/`move` check for cancellation between sources
    /// (`FileSystemServiceImpl`) - already-processed files stay in place.
    ///
    /// Classic mc parity: the progress dialog is shown by default (`background == false`,
    /// the normal OK button) - `background == true` is the explicit "Segundo plano" opt-in
    /// from `CopyMoveDialog`, which runs the exact same operation but never opens a
    /// window for it.
    private func runWithProgress(_ plan: CopyMovePlan, mode: OperationMode, background: Bool) async {
        var continuation: AsyncStream<OperationProgress>.Continuation!
        let stream = AsyncStream<OperationProgress> { continuation = $0 }

        let task = Task<OperationResult, Error> {
            defer { continuation.finish() }
            return mode == .copy
                ? try await fileSystemService.copy(plan, onProgress: { continuation.yield($0) })
                : try await fileSystemService.move(plan, onProgress: { continuation.yield($0) })
        }
        operationTask = task

        let progressViewModel = ProgressDialogViewModel(onCancel: { task.cancel() })
        if !background {
            onShowProgress(progressViewModel)
        }
        async let consuming: Void = progressViewModel.consume(stream)

        do {
            let result = try await task.value
            operationErrorMessage = Self.fo15Message(from: result)
        } catch is CancellationError {
            // FO-16: cancelled by the user - not a failure to surface as an error.
        } catch {
            operationErrorMessage = error.localizedDescription
        }

        await consuming
        operationTask = nil
    }

    /// Presents `ConflictDialog` for `destinationPath` and suspends until the user picks
    /// Overwrite/Skip/Rename/Cancel.
    private func resolveConflict(destinationPath: URL) async -> FileConflictResolution {
        await withCheckedContinuation { continuation in
            conflictDialogViewModel = ConflictDialogViewModel(destinationPath: destinationPath) { resolution in
                conflictDialogViewModel = nil
                continuation.resume(returning: resolution)
            }
        }
    }

    // MARK: - Pure helpers (unit-tested; the body above is thin declarative glue)

    /// What double-click/Enter (`activate`) does with `entry` (FS-04, KN-11): a directory
    /// (the ".." entry included, since it's just a directory whose path is the parent)
    /// navigates there; anything else opens in the viewer.
    enum ActivationResult: Equatable {
        case navigate(URL)
        case view(FileEntry)
    }

    static func activationResult(for entry: FileEntry) -> ActivationResult {
        entry.type == .directory ? .navigate(entry.path) : .view(entry)
    }

    /// A fixed identity for the synthetic ".." row so `List`'s diffing treats it as the
    /// same row across every re-render (a fresh `UUID()` per computed-property evaluation
    /// would make `List`/`selection` treat it as a new row each time).
    static let parentEntryID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Builds the synthetic ".." row for `currentPath` (FS-05, KN-11), or `nil` at the
    /// filesystem root, where `deletingLastPathComponent()` returns the same path and
    /// there is nothing to go up to.
    static func parentEntry(for currentPath: URL) -> FileEntry? {
        let parent = currentPath.deletingLastPathComponent()
        guard parent.path != currentPath.path else { return nil }
        return FileEntry(
            id: parentEntryID,
            name: "..",
            path: parent,
            size: 0,
            creationDate: .distantPast,
            modificationDate: .distantPast,
            permissions: [],
            type: .directory,
            isHidden: false,
            isSymlink: false,
            symlinkTarget: nil
        )
    }

    /// The result of resolving every destination-name conflict for a copy/move batch
    /// (FO-05..FO-09): either the (possibly narrowed/renamed) sources to actually run, or
    /// `cancelled` when the user chose Cancel on any one of them - which aborts the whole
    /// batch, not just that file.
    enum ConflictResolutionOutcome: Equatable {
        case proceed(sources: [FileEntry], renames: [UUID: String])
        case cancelled
    }

    /// Applies `resolutions` (one per conflicting source, in the order they were resolved)
    /// to `sources`: Overwrite leaves the source untouched (destination already gets
    /// overwritten unconditionally downstream, FO-06); Skip removes it (FO-07); Rename
    /// claims the next available `CopyMovePlanner.resolvedName` against `existingNames`
    /// plus every name already claimed earlier in this same batch, so two renamed
    /// conflicts in one operation can't collide with each other (FO-08); Cancel stops
    /// processing further resolutions and aborts the entire batch (FO-09), matching the
    /// spec's "Cancel aborts entire operation" - not just the one file being resolved.
    static func applyResolutions(
        sources: [FileEntry],
        resolutions: [(FileEntry, FileConflictResolution)],
        existingNames: Set<String>
    ) -> ConflictResolutionOutcome {
        var remainingSources = sources
        var renames: [UUID: String] = [:]
        var claimedNames = existingNames

        for (entry, resolution) in resolutions {
            switch resolution {
            case .overwrite:
                continue
            case .skip:
                remainingSources.removeAll { $0.id == entry.id }
            case .rename:
                if let newName = CopyMovePlanner.resolvedName(for: entry.name, existingNames: claimedNames) {
                    renames[entry.id] = newName
                    claimedNames.insert(newName)
                }
            case .cancel:
                return .cancelled
            }
        }

        return .proceed(sources: remainingSources, renames: renames)
    }

    /// What Escape does (KN-12, SF-04), in priority order: dismiss an open dialog, else
    /// clear an active filename filter, else clear the selection, else nothing.
    enum EscapeAction: Equatable {
        case dismissSheet
        case clearFilter
        case clearSelection
        case none
    }

    static func escapeAction(hasOpenSheet: Bool, filterText: String, hasSelection: Bool) -> EscapeAction {
        if hasOpenSheet { return .dismissSheet }
        if !filterText.isEmpty { return .clearFilter }
        if hasSelection { return .clearSelection }
        return .none
    }

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

/// F3-F8 (function keys), FS-04/KN-11 (Enter), FS-05 (Backspace) - split out of
/// `PanelView.entryList` (alongside `PanelSelectionKeys` below) so the compiler doesn't
/// have to type-check every `.onKeyPress` in one giant chained expression.
private struct PanelPrimaryKeys: ViewModifier {
    let functionKeys: Set<KeyEquivalent>
    let onFunctionKey: (KeyEquivalent) -> Void
    let onReturn: () -> Bool
    let onBackspace: () -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(keys: functionKeys) { press in
                onFunctionKey(press.key)
                return .handled
            }
            .onKeyPress(.return) {
                onReturn() ? .handled : .ignored
            }
            .onKeyPress(.delete) {
                onBackspace()
                return .handled
            }
    }
}

/// KN-04 (Cmd+Left/Right jump), KN-05/KN-06 (Space/Insert toggle), "*" (select all, see
/// `PanelView.selectAllEntries`), KN-12/SF-04 (Escape) - the other half of
/// `PanelView.entryList`'s keyboard handling, split for the same reason as
/// `PanelPrimaryKeys` above.
///
/// "+"/"-" are secondary keys for Insert/deselect-all (per user report: Mac keyboards
/// often have no dedicated Insert key at all, and this user's keyboard doesn't reliably
/// send it) - "+" mirrors Insert (toggle current row and advance), "-" clears the whole
/// selection, the natural opposite of "*"/select-all. Cmd+I inverts the selection - the
/// classic mc "*" behavior, given its own key since "*" itself became select-all.
private struct PanelSelectionKeys: ViewModifier {
    let insertKey: KeyEquivalent
    let onJumpFirst: () -> Void
    let onJumpLast: () -> Void
    let onToggle: () -> Void
    let onToggleAndAdvance: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onInvertSelection: () -> Void
    let onEscape: () -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                if press.key == .leftArrow {
                    onJumpFirst()
                } else {
                    onJumpLast()
                }
                return .handled
            }
            .onKeyPress(keys: ["i"]) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                onInvertSelection()
                return .handled
            }
            .onKeyPress(keys: [.space, insertKey, "+"]) { press in
                if press.key == .space {
                    onToggle()
                } else {
                    onToggleAndAdvance()
                }
                return .handled
            }
            .onKeyPress(keys: ["*", "-"]) { press in
                if press.key == "*" {
                    onSelectAll()
                } else {
                    onDeselectAll()
                }
                return .handled
            }
            .onKeyPress(.escape) {
                onEscape()
                return .handled
            }
    }
}

/// Installs a real `NSTableView.doubleAction` for double-click-to-activate (FS-04,
/// KN-11) by walking up from an invisible helper view placed inside each row's content -
/// a genuine descendant of the `List`'s backing `NSTableView`, unlike a `.background()`/
/// `.overlay()` attached to the `List` itself, which SwiftUI may render as a sibling
/// rather than a descendant. Harmless to attach per-row: `List` only ever instantiates
/// the handful of currently-visible rows regardless of how many entries there are.
private struct TableDoubleClickInstaller: NSViewRepresentable {
    let entries: [FileEntry]
    let onDoubleClick: (FileEntry) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(entries: entries, onDoubleClick: onDoubleClick)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { [weak view] in
            guard let tableView = view?.enclosingTableView else { return }
            tableView.target = context.coordinator
            tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.entries = entries
        context.coordinator.onDoubleClick = onDoubleClick
    }

    final class Coordinator: NSObject {
        var entries: [FileEntry]
        var onDoubleClick: (FileEntry) -> Void

        init(entries: [FileEntry], onDoubleClick: @escaping (FileEntry) -> Void) {
            self.entries = entries
            self.onDoubleClick = onDoubleClick
        }

        @objc func handleDoubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard entries.indices.contains(row) else { return }
            onDoubleClick(entries[row])
        }
    }
}

private extension NSView {
    var enclosingTableView: NSTableView? {
        var view: NSView? = self
        while let current = view {
            if let tableView = current as? NSTableView { return tableView }
            view = current.superview
        }
        return nil
    }
}
