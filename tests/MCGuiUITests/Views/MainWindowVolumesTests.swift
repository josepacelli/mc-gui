import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

/// Unit tests for `VolumesListViewModel`, the `@Observable` state `MainWindow` extracts
/// for volume listing (VL-01, VL-02, VL-04, T51). `MainWindow.body` itself (the Go menu
/// and sidebar rendering, plus the `NSWorkspace` mount/unmount notification wiring) is
/// thin declarative glue with no additional testable logic - consistent with the Phase 4/9
/// view precedent, it has no XCUITest coverage yet (no Xcode project/scheme exists in this
/// pure-SPM setup).
@Suite("MainWindow volumes")
@MainActor
struct MainWindowVolumesTests {

    // MARK: - init / refresh (VL-01, VL-02 data)

    @Test("init populates volumes from the injected FileSystemService")
    func initPopulatesVolumesFromService() {
        let expected = [VolumeInfo(name: "Macintosh HD", mountPoint: URL(fileURLWithPath: "/"), freeSpace: 100)]
        let service = MockFileSystemService(getVolumesImpl: { expected })

        let viewModel = VolumesListViewModel(fileSystemService: service)

        #expect(viewModel.volumes == expected)
    }

    @Test("init with no volumes from the service produces an empty list")
    func initWithNoVolumesProducesEmptyList() {
        let service = MockFileSystemService(getVolumesImpl: { [] })

        let viewModel = VolumesListViewModel(fileSystemService: service)

        #expect(viewModel.volumes.isEmpty)
    }

    // MARK: - refresh (VL-04: mount/unmount updates)

    @Test("refresh re-fetches volumes, picking up a newly mounted volume")
    func refreshPicksUpNewlyMountedVolume() {
        let box = VolumesBox(volumes: [])
        let service = MockFileSystemService(getVolumesImpl: { box.volumes })
        let viewModel = VolumesListViewModel(fileSystemService: service)
        #expect(viewModel.volumes.isEmpty)

        box.volumes = [VolumeInfo(name: "USB Drive", mountPoint: URL(fileURLWithPath: "/Volumes/USB"), freeSpace: 500)]
        viewModel.refresh()

        #expect(viewModel.volumes.map(\.name) == ["USB Drive"])
    }

    @Test("refresh drops a volume the service no longer reports (unmount)")
    func refreshDropsUnmountedVolume() {
        let box = VolumesBox(volumes: [VolumeInfo(name: "USB Drive", mountPoint: URL(fileURLWithPath: "/Volumes/USB"), freeSpace: 500)])
        let service = MockFileSystemService(getVolumesImpl: { box.volumes })
        let viewModel = VolumesListViewModel(fileSystemService: service)
        #expect(viewModel.volumes.count == 1)

        box.volumes = []
        viewModel.refresh()

        #expect(viewModel.volumes.isEmpty)
    }
}

/// A mutable box so tests can change what `MockFileSystemService.getVolumesImpl` returns
/// between an initial read and a later `refresh()` call, simulating a mount/unmount.
/// Deliberately not actor-isolated (mirrors `ReadCounter` in
/// `ViewerServiceImplLoadTests`) so it can be captured by `getVolumesImpl`'s `@Sendable`
/// closure type.
private final class VolumesBox {
    var volumes: [VolumeInfo]
    init(volumes: [VolumeInfo]) { self.volumes = volumes }
}
