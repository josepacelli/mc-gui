import Foundation
import Observation
import MCGuiCore

@MainActor
@Observable
public final class ProgressDialogViewModel {
    public private(set) var currentFile: String = ""
    public private(set) var filesProcessed: Int = 0
    public private(set) var totalFiles: Int = 0
    public private(set) var bytesTransferred: Int64 = 0
    public private(set) var totalBytes: Int64 = 0
    public private(set) var speed: Double = 0
    public private(set) var eta: TimeInterval = 0
    public private(set) var isCompleted = false
    public private(set) var isCancelled = false

    private let onCancel: () -> Void

    public init(onCancel: @escaping () -> Void = {}) {
        self.onCancel = onCancel
    }

    public func consume(_ stream: AsyncStream<OperationProgress>) async {
        for await progress in stream {
            apply(progress)
        }
        isCompleted = true
    }

    private func apply(_ progress: OperationProgress) {
        currentFile = progress.currentFile
        filesProcessed = progress.filesProcessed
        totalFiles = progress.totalFiles
        bytesTransferred = progress.bytesTransferred
        totalBytes = progress.totalBytes
        speed = progress.speed
        eta = progress.eta
    }

    public func cancel() {
        isCancelled = true
        onCancel()
    }
}
