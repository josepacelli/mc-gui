import SwiftUI
import AppKit
import MCGuiCore

@MainActor
public struct PanelView: View {
    public let viewModel: PanelViewModel
    public let isActive: Bool
    public var onActivate: () -> Void
    public var onViewFile: (FileEntry) -> Void
    public var onEditFile: (FileEntry) -> Void
    public var onShowProgress: (ProgressDialogViewModel) -> Void
    public var onHelp: () -> Void
    public var onUserMenu: (UserMenuContext) -> Void
    public var pendingAction: Binding<PanelAction?>
    public var otherPanelPath: URL?
    public var onOperationCompleted: () -> Void

    @FocusState private var isFocused: Bool
    @State private var selection: Set<UUID> = []
    @State private var markedIDs: Set<UUID> = []

    @State private var copyMoveViewModel: CopyMoveDialogViewModel?
    @State private var conflictDialogViewModel: ConflictDialogViewModel?
    @State private var mkdirViewModel: MkdirDialogViewModel?
    @State private var deleteViewModel: DeleteConfirmDialogViewModel?
    @State private var goToFolderViewModel: GoToFolderDialogViewModel?
    @State private var operationErrorMessage: String?
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


    private static let f1Key = KeyEquivalent(Character(UnicodeScalar(NSF1FunctionKey)!))
    private static let f2Key = KeyEquivalent(Character(UnicodeScalar(NSF2FunctionKey)!))
    private static let f3Key = KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!))
    private static let f4Key = KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!))
    private static let f5Key = KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))
    private static let f6Key = KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))
    private static let f7Key = KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))
    private static let f8Key = KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))
    private static let insertKey = KeyEquivalent(Character(UnicodeScalar(NSInsertFunctionKey)!))

    private var fileSystemService: FileSystemService { viewModel.fileSystemService }

    private var selectedEntries: [FileEntry] {
        viewModel.entries.filter { selection.contains($0.id) }
    }

    private var selectedDisplayEntries: [FileEntry] {
        displayEntries.filter { selection.contains($0.id) }
    }

    private var markedEntries: [FileEntry] {
        viewModel.entries.filter { markedIDs.contains($0.id) }
    }

    private var operationEntries: [FileEntry] {
        markedEntries.isEmpty ? selectedEntries : markedEntries
    }

    private var displayedErrorMessage: String? {
        operationErrorMessage ?? viewModel.errorMessage
    }

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
        .sheet(isPresented: presented($goToFolderViewModel)) {
            if let goToFolderViewModel {
                GoToFolderDialog(viewModel: goToFolderViewModel, onCancel: { self.goToFolderViewModel = nil })
            }
        }
        .onChange(of: mkdirViewModel?.isCompleted) { _, completed in
            guard completed == true else { return }
            mkdirViewModel = nil
            Task { await viewModel.load() }
        }
        .onChange(of: goToFolderViewModel?.isCompleted) { _, completed in
            guard completed == true, let target = goToFolderViewModel?.resultPath else { return }
            goToFolderViewModel = nil
            Task { await viewModel.load(target) }
        }
        .onChange(of: deleteViewModel?.isCompleted) { _, completed in
            guard completed == true else { return }
            deleteViewModel = nil
            markedIDs = []
            Task { await viewModel.load() }
        }
    }

    private var entryList: some View {
        List(displayEntries, selection: $selection) { entry in
            FileRow(entry: entry, isMarked: markedIDs.contains(entry.id))
                .contextMenu {
                    Text(entry.name)
                }
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


    private var header: some View {
        HStack(spacing: 4) {
            Text(viewModel.currentPath.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: beginGoToFolder)

            Button(action: beginGoToFolder) {
                Image(systemName: "arrow.right.square")
            }
            .buttonStyle(.plain)
            .help(String(localized: "goToFolder.title", bundle: .module, comment: "Go to Folder dialog title"))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isActive ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.15))
    }

    private func beginGoToFolder() {
        goToFolderViewModel = GoToFolderDialogViewModel(fileSystemService: fileSystemService, currentPath: viewModel.currentPath)
    }

    private var footer: some View {
        HStack {
            if markedIDs.isEmpty {
                Text(
                    String(
                        format: NSLocalizedString(
                            "panel.footer.fileCount",
                            bundle: .module,
                            comment: "Panel footer: total entry count when nothing is selected. %1$d is the count."
                        ),
                        viewModel.entries.count
                    )
                )
            } else {
                Text(
                    String(
                        format: NSLocalizedString(
                            "panel.footer.selectionCount",
                            bundle: .module,
                            comment: "Panel footer: selected-of-total count. %1$d is the selected count, %2$d is the total count."
                        ),
                        markedIDs.count, viewModel.entries.count
                    )
                )
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
        if key.character == Self.f1Key.character {
            onHelp()
            return
        }
        guard let action = Self.action(forKey: key) else { return }
        perform(action)
    }

    private func activateSelected() -> Bool {
        guard let entry = Self.targetEntry(selection: selectedDisplayEntries) else { return false }
        activate(entry)
        return true
    }

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

    private func beginUserMenu() {
        onUserMenu(UserMenuContext(
            currentFile: selectedEntries.first?.path,
            currentDir: viewModel.currentPath,
            otherDir: otherPanelPath ?? viewModel.currentPath
        ))
    }

    private func beginView() {
        guard let entry = Self.targetEntry(selection: selectedEntries) else { return }
        onViewFile(entry)
    }

    private func beginEdit() {
        guard let entry = Self.targetEntry(selection: selectedEntries) else { return }
        onEditFile(entry)
    }

    private func beginCopyOrMove(_ mode: OperationMode) {
        guard operationTask == nil else { return }
        operationErrorMessage = nil
        copyMoveViewModel = Self.makeCopyMoveDialog(
            selection: operationEntries,
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
            selection: operationEntries,
            trashService: FileSystemTrashAdapter(fileSystemService: fileSystemService)
        )
    }

    private func activate(_ entry: FileEntry) {
        switch Self.activationResult(for: entry) {
        case .navigate(let target):
            Task { await viewModel.load(target) }
        case .view(let file):
            onViewFile(file)
        }
    }

    private func navigateToParent() {
        Task { await viewModel.load(viewModel.currentPath.deletingLastPathComponent()) }
    }

    private func jumpToEdge(first: Bool) {
        guard let target = PanelCommands.jump(toFirst: first, entries: displayEntries) else { return }
        selection = [target]
    }

    private func toggleCurrentSelection() {
        guard let currentID = currentRowID else { return }
        markedIDs = PanelCommands.toggleSelection(markedIDs, id: currentID, entries: displayEntries)
    }

    private func toggleAndAdvanceSelection() {
        guard let currentID = currentRowID else { return }
        let result = PanelCommands.toggleAndAdvance(markedIDs, id: currentID, entries: displayEntries)
        markedIDs = result.selection
        if let next = result.nextCursor {
            selection = [next]
        }
    }

    private var currentRowID: FileEntry.ID? {
        selection.first ?? displayEntries.first?.id
    }

    private func selectAllEntries() {
        markedIDs = PanelCommands.selectAll(entries: viewModel.entries)
    }

    private func deselectAllEntries() {
        markedIDs = PanelCommands.deselectAll()
    }

    private func invertSelection() {
        markedIDs = PanelCommands.invertSelection(markedIDs, entries: viewModel.entries)
    }

    private func handleEscape() {
        switch Self.escapeAction(hasOpenSheet: hasOpenSheet, filterText: viewModel.filterText, hasSelection: !markedIDs.isEmpty) {
        case .dismissSheet:
            conflictDialogViewModel = nil
            copyMoveViewModel = nil
            mkdirViewModel = nil
            deleteViewModel = nil
        case .clearFilter:
            viewModel.clearFilter()
        case .clearSelection:
            markedIDs = []
        case .none:
            break
        }
    }

    private var hasOpenSheet: Bool {
        conflictDialogViewModel != nil || copyMoveViewModel != nil || mkdirViewModel != nil || deleteViewModel != nil
            || goToFolderViewModel != nil
    }

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
        } catch {
            operationErrorMessage = error.localizedDescription
        }

        await consuming
        operationTask = nil
    }

    private func resolveConflict(destinationPath: URL) async -> FileConflictResolution {
        await withCheckedContinuation { continuation in
            conflictDialogViewModel = ConflictDialogViewModel(destinationPath: destinationPath) { resolution in
                conflictDialogViewModel = nil
                continuation.resume(returning: resolution)
            }
        }
    }


    enum ActivationResult: Equatable {
        case navigate(URL)
        case view(FileEntry)
    }

    static func activationResult(for entry: FileEntry) -> ActivationResult {
        entry.type == .directory ? .navigate(entry.path) : .view(entry)
    }

    static let parentEntryID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static func parentEntry(for currentPath: URL) -> FileEntry? {
        guard currentPath.path != "/" else { return nil }
        let parent = currentPath.deletingLastPathComponent()
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

    enum ConflictResolutionOutcome: Equatable {
        case proceed(sources: [FileEntry], renames: [UUID: String])
        case cancelled
    }

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

    static func targetEntry(selection: [FileEntry]) -> FileEntry? {
        selection.first
    }

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

    static func makeMkdirDialog(fileSystemService: FileSystemService, parentDirectory: URL) -> MkdirDialogViewModel {
        MkdirDialogViewModel(fileSystemService: fileSystemService, parentDirectory: parentDirectory)
    }

    static func makeDeleteDialog(selection: [FileEntry], trashService: TrashService) -> DeleteConfirmDialogViewModel? {
        guard !selection.isEmpty else { return nil }
        return DeleteConfirmDialogViewModel(trashService: trashService, entries: selection)
    }

    static func fo15Message(from result: OperationResult) -> String? {
        guard !result.success, let firstFailure = result.failedItems.first else { return nil }
        if result.failedItems.count == 1 {
            return String(
                format: NSLocalizedString(
                    "panel.operationFailure.single",
                    bundle: .module,
                    comment: "FO-15: single file-operation failure. %1$@ is the file path, %2$@ is the failure reason."
                ),
                firstFailure.path, firstFailure.reason
            )
        }
        return String(
            format: NSLocalizedString(
                "panel.operationFailure.multiple",
                bundle: .module,
                comment: "FO-15: multiple file-operation failures. %1$@ is the first failing file's path, %2$@ is its failure reason, %3$d is the count of additional failures."
            ),
            firstFailure.path, firstFailure.reason, result.failedItems.count - 1
        )
    }
}

private struct FileSystemTrashAdapter: TrashService {
    let fileSystemService: FileSystemService

    func trash(_ urls: [URL]) async throws -> OperationResult {
        try await fileSystemService.trash(urls)
    }
}

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
                guard press.modifiers.contains(.command) || press.modifiers.contains(.control) else { return .ignored }
                onInvertSelection()
                return .handled
            }
            .onKeyPress(keys: ["a", "u", "t"]) { press in
                guard press.modifiers.contains(.control) else { return .ignored }
                switch press.key {
                case "a": onSelectAll()
                case "u": onDeselectAll()
                case "t": onToggleAndAdvance()
                default: return .ignored
                }
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
