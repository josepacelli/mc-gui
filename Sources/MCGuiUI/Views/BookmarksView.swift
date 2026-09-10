import SwiftUI

/// A bookmarked directory as `BookmarksView` renders it - a lightweight, `MCGuiUI`-local
/// model decoupled from `MCGuiMacOS`'s `Bookmark` (T53): `MCGuiUI` does not depend on
/// `MCGuiMacOS`, so this module cannot reference that concrete type directly, mirroring how
/// `ViewerWindow`/`EditorWindow` depend only on `MCGuiCore` protocols rather than
/// `MCGuiMacOS`'s service implementations (T38, T43). A future `MCGuiApp` bridge maps
/// between the two, the same way `WindowManager` bridges `ViewerService`/`EditorService`.
public struct BookmarkEntry: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let path: URL

    public init(id: UUID = UUID(), name: String, path: URL) {
        self.id = id
        self.name = name
        self.path = path
    }
}

/// Persistence actions `BookmarksViewModel` delegates to - injected by the caller so this
/// module never needs to import `MCGuiMacOS`'s concrete `BookmarkStore` (mirrors
/// `AppCommandActions`/`KeyboardShortcutActions`, T44/T48).
public struct BookmarksActions {
    public var list: () async throws -> [BookmarkEntry]
    public var add: (BookmarkEntry) async throws -> Void
    public var remove: (UUID) async throws -> Void

    public init(
        list: @escaping () async throws -> [BookmarkEntry] = { [] },
        add: @escaping (BookmarkEntry) async throws -> Void = { _ in },
        remove: @escaping (UUID) async throws -> Void = { _ in }
    ) {
        self.list = list
        self.add = add
        self.remove = remove
    }
}

/// Bookmarks list state (BM-02 data): loads from the injected `BookmarksActions`, and
/// keeps `bookmarks` in sync after adding (BM-01) or removing (BM-04).
@MainActor
@Observable
public final class BookmarksViewModel {
    private let actions: BookmarksActions
    public private(set) var bookmarks: [BookmarkEntry] = []
    public private(set) var errorMessage: String?

    public init(actions: BookmarksActions) {
        self.actions = actions
    }

    /// Reloads `bookmarks` from the injected `list` action.
    public func refresh() async {
        do {
            bookmarks = try await actions.list()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Adds `directory` as a bookmark named after its last path component (BM-01), then
    /// refreshes `bookmarks` to reflect the persisted state.
    public func addBookmark(for directory: URL) async {
        let entry = BookmarkEntry(name: directory.lastPathComponent, path: directory)
        do {
            try await actions.add(entry)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes the bookmark with `id` (BM-04), then refreshes `bookmarks`.
    public func remove(id: UUID) async {
        do {
            try await actions.remove(id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Bookmarks sidebar (BM-02): an "Add" button bound to Cmd+D adds `activeDirectory`
/// (BM-01), selecting a row navigates there via `onNavigate`, and each row's remove
/// control deletes it (BM-04). Persistence across launches (BM-03) is the injected
/// `BookmarksActions`' responsibility (backed by `MCGuiMacOS`'s `BookmarkStore`, T53).
public struct BookmarksView: View {
    public let viewModel: BookmarksViewModel
    public var activeDirectory: URL
    public var onNavigate: (URL) -> Void

    public init(
        viewModel: BookmarksViewModel,
        activeDirectory: URL,
        onNavigate: @escaping (URL) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.activeDirectory = activeDirectory
        self.onNavigate = onNavigate
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Bookmarks").font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.addBookmark(for: activeDirectory) }
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("d", modifiers: .command)
                .help("Add Bookmark (⌘D)")
            }
            .padding(8)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
            }

            List(viewModel.bookmarks) { bookmark in
                HStack {
                    Button(bookmark.name) { onNavigate(bookmark.path) }
                        .buttonStyle(.plain)
                    Spacer()
                    Button {
                        Task { await viewModel.remove(id: bookmark.id) }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Remove Bookmark")
                }
            }
        }
        .task { await viewModel.refresh() }
    }
}
