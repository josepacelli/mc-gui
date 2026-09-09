import Foundation
import MCGuiCore

/// A `FileSystemService` test double with an injectable `listDirectory` behavior.
/// The other protocol methods aren't exercised by the ViewModel tests in this target and
/// return trivial success values.
struct MockFileSystemService: FileSystemService {
    var listDirectoryImpl: @Sendable (URL) async throws -> [FileEntry]

    init(listDirectoryImpl: @escaping @Sendable (URL) async throws -> [FileEntry] = { _ in [] }) {
        self.listDirectoryImpl = listDirectoryImpl
    }

    func listDirectory(_ url: URL) async throws -> [FileEntry] {
        try await listDirectoryImpl(url)
    }

    func createDirectory(_ url: URL) async throws {}

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
