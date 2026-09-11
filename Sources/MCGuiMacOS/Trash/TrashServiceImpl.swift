import Foundation
import MCGuiCore

/// `TrashService` implementation backed by `FileManager.trashItem(at:resultingItemURL:)`,
/// moving files to the macOS Trash instead of deleting them permanently (FO-12/FO-13).
public final class TrashServiceImpl: TrashService {
    /// Trashes a single item and returns where it landed. Injectable so tests can
    /// observe the resulting Trash URL directly (`FileManager.fileExists` on a known
    /// path) without needing to enumerate `~/.Trash`, which TCC can deny independently
    /// of the (privileged) `trashItem` call itself.
    private let trashItem: (URL) throws -> URL?

    public init(fileManager: FileManager = .default) {
        self.trashItem = { url in
            var resultingItemURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingItemURL)
            return resultingItemURL as URL?
        }
    }

    init(trashItem: @escaping (URL) throws -> URL?) {
        self.trashItem = trashItem
    }

    public func trash(_ urls: [URL]) async throws -> OperationResult {
        var failedItems: [FailedItem] = []
        var processedCount = 0

        for url in urls {
            do {
                _ = try trashItem(url)
                processedCount += 1
            } catch {
                failedItems.append(FailedItem(path: url.path, reason: error.localizedDescription))
            }
        }

        return OperationResult(
            success: failedItems.isEmpty,
            errorMessage: failedItems.isEmpty ? nil : String(localized: "operationResult.error.trashFailed", bundle: .module, comment: "Summary error when one or more items could not be moved to Trash"),
            processedCount: processedCount,
            failedItems: failedItems
        )
    }
}
