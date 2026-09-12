import Foundation

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

public protocol FileSystemService {
    func listDirectory(_ url: URL) async throws -> [FileEntry]

    func createDirectory(_ url: URL) async throws

    func copy(_ plan: CopyMovePlan) async throws -> OperationResult

    func move(_ plan: CopyMovePlan) async throws -> OperationResult

    func copy(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult

    func move(_ plan: CopyMovePlan, onProgress: @escaping (OperationProgress) -> Void) async throws -> OperationResult

    func trash(_ urls: [URL]) async throws -> OperationResult

    func getVolumes() -> [VolumeInfo]

    func zip(_ sources: [FileEntry], to destination: URL) async throws
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

    /// Default placeholder so existing conformers keep building until a concrete
    /// implementation (`FileSystemServiceImpl`, MCGuiMacOS) is added.
    func zip(_ sources: [FileEntry], to destination: URL) async throws {
        throw CocoaError(.featureUnsupported)
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
