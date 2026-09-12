import Foundation
import Observation
import MCGuiCore

@MainActor
@Observable
public final class InfoDialogViewModel {
    private let fileSystemService: FileSystemService
    public let entry: FileEntry

    public private(set) var totalSize: Int64?
    public private(set) var itemCount: Int?

    public init(entry: FileEntry, fileSystemService: FileSystemService) {
        self.entry = entry
        self.fileSystemService = fileSystemService
        if entry.type != .directory {
            totalSize = entry.size
        }
    }

    public func startSizeCalculationIfNeeded() async {
        guard entry.type == .directory else { return }
        let result = await recursiveSizeAndCount(at: entry.path)
        guard !Task.isCancelled else { return }
        totalSize = result.size
        itemCount = result.count
    }

    private func recursiveSizeAndCount(at url: URL) async -> (size: Int64, count: Int) {
        guard !Task.isCancelled else { return (0, 0) }
        let entries = (try? await fileSystemService.listDirectory(url)) ?? []

        var size: Int64 = 0
        var count = 0
        for child in entries {
            guard !Task.isCancelled else { break }
            count += 1
            if child.type == .directory {
                let nested = await recursiveSizeAndCount(at: child.path)
                size += nested.size
                count += nested.count
            } else {
                size += child.size
            }
        }
        return (size, count)
    }
}
