import Foundation

// SPEC_DEVIATION: `VolumeInfo` is not among the 13 domain models spec.md's SWIFT-02
// enumerates, but design.md's FileSystemServiceImpl Key Methods require a return type
// for `getVolumes()`. Defined here as the minimal supporting type needed for the
// protocol signature to compile; fields (name, mountPoint, freeSpace) match what T14
// (getVolumes implementation) needs.
/// A mounted filesystem volume.
public struct VolumeInfo: Identifiable, Hashable, Codable {
    public let id: UUID
    public let name: String
    public let mountPoint: URL
    public let freeSpace: Int64

    public init(id: UUID = UUID(), name: String, mountPoint: URL, freeSpace: Int64) {
        self.id = id
        self.name = name
        self.mountPoint = mountPoint
        self.freeSpace = freeSpace
    }
}

/// Filesystem access: directory listing, directory creation, copy/move, trash, volumes.
public protocol FileSystemService {
    func listDirectory(_ url: URL) async throws -> [FileEntry]

    func createDirectory(_ url: URL) async throws

    func copy(_ plan: CopyMovePlan) async throws -> OperationResult

    func move(_ plan: CopyMovePlan) async throws -> OperationResult

    // FO-14, FO-16: progress-reporting variants `PanelView`'s `ProgressDialog` consumes -
    // `onProgress` is called once per source processed, and cancelling the enclosing
    // `Task` (checked between sources) aborts the operation. Default implementations
    // below fall back to a single before/after snapshot for conformers that don't
    // override them; `FileSystemServiceImpl` overrides both with real per-file progress.
    func copy(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult

    func move(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult

    func trash(_ urls: [URL]) async throws -> OperationResult

    func getVolumes() -> [VolumeInfo]
}

public extension FileSystemService {
    func copy(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult {
        let result = try await copy(plan)
        onProgress(Self.finalProgress(for: plan))
        return result
    }

    func move(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult {
        let result = try await move(plan)
        onProgress(Self.finalProgress(for: plan))
        return result
    }

    private static func finalProgress(for plan: CopyMovePlan) -> OperationProgress {
        let totalBytes = plan.sources.reduce(Int64(0)) { $0 + $1.size }
        return OperationProgress(
            currentFile: plan.sources.last?.name ?? "",
            filesProcessed: plan.sources.count,
            totalFiles: plan.sources.count,
            bytesTransferred: totalBytes,
            totalBytes: totalBytes,
            speed: 0,
            eta: 0
        )
    }
}
