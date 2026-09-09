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

    func trash(_ urls: [URL]) async throws -> OperationResult

    func getVolumes() -> [VolumeInfo]
}
