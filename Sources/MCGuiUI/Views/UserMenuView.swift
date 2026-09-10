import SwiftUI

/// The active panel's context when F2 (User Menu) opens: which file/directories `%f`/
/// `%d`/`%D` expand to (`UserMenuRunner`, `MCGuiMacOS`).
public struct UserMenuContext: Equatable {
    public var currentFile: URL?
    public var currentDir: URL
    public var otherDir: URL

    public init(currentFile: URL?, currentDir: URL, otherDir: URL) {
        self.currentFile = currentFile
        self.currentDir = currentDir
        self.otherDir = otherDir
    }
}

/// One user-defined menu item as `UserMenuView` renders it - a lightweight, `MCGuiUI`-
/// local model decoupled from `MCGuiMacOS`'s concrete `UserMenuItem`, mirroring
/// `BookmarkEntry`/`Bookmark`.
public struct UserMenuEntry: Identifiable, Hashable {
    public let id: UUID
    public let label: String
    public let command: String

    public init(id: UUID = UUID(), label: String, command: String) {
        self.id = id
        self.label = label
        self.command = command
    }
}

/// The result of running one User Menu command.
public struct UserMenuRunResult: Equatable {
    public var output: String
    public var exitCode: Int32

    public init(output: String, exitCode: Int32) {
        self.output = output
        self.exitCode = exitCode
    }
}

/// Persistence + execution actions `UserMenuViewModel` delegates to - injected by the
/// caller so this module never needs to import `MCGuiMacOS`'s concrete `UserMenuStore`/
/// `UserMenuRunner` (mirrors `BookmarksActions`).
public struct UserMenuActions {
    public var list: () async throws -> [UserMenuEntry]
    public var add: (UserMenuEntry) async throws -> Void
    public var remove: (UUID) async throws -> Void
    public var run: (UserMenuEntry, UserMenuContext) async -> UserMenuRunResult

    public init(
        list: @escaping () async throws -> [UserMenuEntry] = { [] },
        add: @escaping (UserMenuEntry) async throws -> Void = { _ in },
        remove: @escaping (UUID) async throws -> Void = { _ in },
        run: @escaping (UserMenuEntry, UserMenuContext) async -> UserMenuRunResult = { _, _ in
            UserMenuRunResult(output: "", exitCode: 0)
        }
    ) {
        self.list = list
        self.add = add
        self.remove = remove
        self.run = run
    }
}

/// User Menu list state (F2): loads from the injected `UserMenuActions`, keeps `items` in
/// sync after adding/removing, and tracks the last run's output.
@MainActor
@Observable
public final class UserMenuViewModel {
    private let actions: UserMenuActions
    public private(set) var items: [UserMenuEntry] = []
    public private(set) var errorMessage: String?
    public private(set) var lastResult: UserMenuRunResult?
    public private(set) var isRunning = false

    public init(actions: UserMenuActions) {
        self.actions = actions
    }

    /// Reloads `items` from the injected `list` action.
    public func refresh() async {
        do {
            items = try await actions.list()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Adds a new item with `label`/`command` (both required), then refreshes `items`.
    public func addItem(label: String, command: String) async {
        guard !label.isEmpty, !command.isEmpty else { return }
        do {
            try await actions.add(UserMenuEntry(label: label, command: command))
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes the item with `id`, then refreshes `items`.
    public func remove(id: UUID) async {
        do {
            try await actions.remove(id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Runs `item` against `context`, recording the result in `lastResult`.
    public func run(_ item: UserMenuEntry, context: UserMenuContext) async {
        isRunning = true
        lastResult = nil
        lastResult = await actions.run(item, context)
        isRunning = false
    }
}

/// The F2 User Menu window: an editable list of commands (add/run/remove) plus the last
/// run's output. Scoped down from the original mc's tree-structured, drag-and-drop menu
/// editor with submenus/conditions to a flat, always-visible list - real utility,
/// contained scope, mirroring `BookmarksView`'s own simplification.
public struct UserMenuView: View {
    public let viewModel: UserMenuViewModel
    public var context: UserMenuContext

    @State private var newLabel = ""
    @State private var newCommand = ""
    @State private var showingAddForm = false

    public init(viewModel: UserMenuViewModel, context: UserMenuContext) {
        self.viewModel = viewModel
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("User Menu").font(.headline)
                Spacer()
                Button {
                    showingAddForm.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Command")
            }
            .padding(8)

            if showingAddForm {
                addForm
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
            }

            List(viewModel.items) { item in
                itemRow(item)
            }

            resultArea
        }
        .task { await viewModel.refresh() }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Label", text: $newLabel)
            TextField("Command (%f file, %d dir, %D other dir)", text: $newCommand)
            HStack {
                Spacer()
                Button("Cancel") { cancelAddForm() }
                Button("Add") {
                    Task {
                        await viewModel.addItem(label: newLabel, command: newCommand)
                        cancelAddForm()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newLabel.isEmpty || newCommand.isEmpty)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func cancelAddForm() {
        newLabel = ""
        newCommand = ""
        showingAddForm = false
    }

    private func itemRow(_ item: UserMenuEntry) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.label)
                Text(item.command)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Run") { Task { await viewModel.run(item, context: context) } }
            Button {
                Task { await viewModel.remove(id: item.id) }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
    }

    @ViewBuilder
    private var resultArea: some View {
        if viewModel.isRunning {
            ProgressView()
                .padding(8)
        } else if let result = viewModel.lastResult {
            Divider()
            ScrollView {
                Text(result.output.isEmpty ? "(no output)" : result.output)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(result.exitCode == 0 ? Color.primary : Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 150)
            Text("Exit code: \(result.exitCode)")
                .font(.caption2)
                .foregroundStyle(result.exitCode == 0 ? Color.secondary : Color.red)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
    }
}
