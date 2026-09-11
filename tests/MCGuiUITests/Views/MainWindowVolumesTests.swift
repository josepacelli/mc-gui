import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("MainWindow volumes")
@MainActor
struct MainWindowVolumesTests {


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

private final class VolumesBox {
    var volumes: [VolumeInfo]
    init(volumes: [VolumeInfo]) { self.volumes = volumes }
}
