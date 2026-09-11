import SwiftUI

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

@MainActor
@Observable
public final class BookmarksViewModel {
    private let actions: BookmarksActions
    public private(set) var bookmarks: [BookmarkEntry] = []
    public private(set) var errorMessage: String?

    public init(actions: BookmarksActions) {
        self.actions = actions
    }

    public func refresh() async {
        do {
            bookmarks = try await actions.list()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addBookmark(for directory: URL) async {
        let entry = BookmarkEntry(name: directory.lastPathComponent, path: directory)
        do {
            try await actions.add(entry)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func remove(id: UUID) async {
        do {
            try await actions.remove(id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
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
                Text(String(localized: "bookmarks.header.title", bundle: .module, comment: "Bookmarks popover title"))
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.addBookmark(for: activeDirectory) }
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("d", modifiers: .command)
                .help(String(localized: "bookmarks.button.add.help", bundle: .module, comment: "Add-bookmark button tooltip (⌘D unchanged)"))
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
                    .help(String(localized: "bookmarks.button.remove.help", bundle: .module, comment: "Remove-bookmark button tooltip"))
                }
            }
        }
        .task { await viewModel.refresh() }
    }
}
