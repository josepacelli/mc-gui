import Foundation
import MCGuiCore

/// A `FileSystemService` test double with injectable `listDirectory`/`createDirectory`
/// behaviors. The other protocol methods aren't exercised by the ViewModel tests in this
/// target and return trivial success values.
struct MockFileSystemService: FileSystemService {
    var listDirectoryImpl: @Sendable (URL) async throws -> [FileEntry]
    var createDirectoryImpl: @Sendable (URL) async throws -> Void

    // `createDirectoryImpl` is declared before `listDirectoryImpl` so existing unlabeled
    // trailing-closure call sites (`MockFileSystemService { ... }`) keep binding to
    // `listDirectoryImpl`, the last parameter.
    init(
        createDirectoryImpl: @escaping @Sendable (URL) async throws -> Void = { _ in },
        listDirectoryImpl: @escaping @Sendable (URL) async throws -> [FileEntry] = { _ in [] }
    ) {
        self.createDirectoryImpl = createDirectoryImpl
        self.listDirectoryImpl = listDirectoryImpl
    }

    func listDirectory(_ url: URL) async throws -> [FileEntry] {
        try await listDirectoryImpl(url)
    }

    func createDirectory(_ url: URL) async throws {
        try await createDirectoryImpl(url)
    }

    func copy(_ plan: CopyMovePlan) async throws -> OperationResult {
        OperationResult(success: true, errorMessage: nil, processedCount: 0, failedItems: [])
    }

    func move(_ plan: CopyMovePlan) async throws -> OperationResult {
        OperationResult(success: true, errorMessage: nil, processedCount: 0, failedItems: [])
    }

    func trash(_ urls: [URL]) async throws -> OperationResult {
        OperationResult(success: true, errorMessage: nil, processedCount: 0, failedItems: [])
    }

    func getVolumes() -> [VolumeInfo] { [] }
}

struct MockError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// A `TrashService` test double with an injectable `trash` behavior.
struct MockTrashService: TrashService {
    var trashImpl: @Sendable ([URL]) async throws -> OperationResult

    init(trashImpl: @escaping @Sendable ([URL]) async throws -> OperationResult = { urls in
        OperationResult(success: true, errorMessage: nil, processedCount: urls.count, failedItems: [])
    }) {
        self.trashImpl = trashImpl
    }

    func trash(_ urls: [URL]) async throws -> OperationResult {
        try await trashImpl(urls)
    }
}

/// A `ViewerService` test double with injectable `load`/`nextFile`/`previousFile`/`search`
/// behaviors, for `ViewerViewModelTests`.
struct MockViewerService: ViewerService {
    var loadImpl: @Sendable (URL) async throws -> ViewerContent
    var nextFileImpl: @Sendable () async throws -> ViewerContent
    var previousFileImpl: @Sendable () async throws -> ViewerContent
    var searchImpl: @Sendable (String) -> [SearchMatch]

    init(
        loadImpl: @escaping @Sendable (URL) async throws -> ViewerContent = { _ in .text("") },
        nextFileImpl: @escaping @Sendable () async throws -> ViewerContent = { .text("") },
        previousFileImpl: @escaping @Sendable () async throws -> ViewerContent = { .text("") },
        searchImpl: @escaping @Sendable (String) -> [SearchMatch] = { _ in [] }
    ) {
        self.loadImpl = loadImpl
        self.nextFileImpl = nextFileImpl
        self.previousFileImpl = previousFileImpl
        self.searchImpl = searchImpl
    }

    func load(_ url: URL) async throws -> ViewerContent { try await loadImpl(url) }
    func nextFile() async throws -> ViewerContent { try await nextFileImpl() }
    func previousFile() async throws -> ViewerContent { try await previousFileImpl() }
    func search(_ query: String) -> [SearchMatch] { searchImpl(query) }
}

func makeTestEntry(
    name: String,
    size: Int64 = 0,
    date: Date = Date(timeIntervalSince1970: 0),
    type: FileType = .file,
    isHidden: Bool = false
) -> FileEntry {
    FileEntry(
        name: name,
        path: URL(fileURLWithPath: "/tmp/\(name)"),
        size: size,
        creationDate: date,
        modificationDate: date,
        permissions: [],
        type: type,
        isHidden: isHidden,
        isSymlink: false,
        symlinkTarget: nil
    )
}
