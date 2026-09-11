import Foundation
import MCGuiCore

struct MockFileSystemService: FileSystemService {
    var listDirectoryImpl: @Sendable (URL) async throws -> [FileEntry]
    var createDirectoryImpl: @Sendable (URL) async throws -> Void
    var getVolumesImpl: @Sendable () -> [VolumeInfo]

    init(
        createDirectoryImpl: @escaping @Sendable (URL) async throws -> Void = { _ in },
        getVolumesImpl: @escaping @Sendable () -> [VolumeInfo] = { [] },
        listDirectoryImpl: @escaping @Sendable (URL) async throws -> [FileEntry] = { _ in [] }
    ) {
        self.createDirectoryImpl = createDirectoryImpl
        self.getVolumesImpl = getVolumesImpl
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

    func getVolumes() -> [VolumeInfo] { getVolumesImpl() }
}

struct MockError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

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

struct MockEditorService: EditorService {
    var openImpl: @Sendable (URL) async throws -> EditorDocumentState
    var saveImpl: @Sendable (EditorDocumentState) async throws -> Void
    var closeImpl: @Sendable () -> Void

    init(
        openImpl: @escaping @Sendable (URL) async throws -> EditorDocumentState = { url in
            EditorDocumentState(content: "", fileURL: url, isDirty: false, encoding: "UTF-8")
        },
        saveImpl: @escaping @Sendable (EditorDocumentState) async throws -> Void = { _ in },
        closeImpl: @escaping @Sendable () -> Void = {}
    ) {
        self.openImpl = openImpl
        self.saveImpl = saveImpl
        self.closeImpl = closeImpl
    }

    func open(_ url: URL) async throws -> EditorDocumentState { try await openImpl(url) }
    func save(_ state: EditorDocumentState) async throws { try await saveImpl(state) }
    func close() { closeImpl() }
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
