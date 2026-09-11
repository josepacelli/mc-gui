import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("ProgressDialogViewModel")
@MainActor
struct ProgressDialogViewModelTests {

    private func progress(
        currentFile: String,
        filesProcessed: Int = 0,
        totalFiles: Int = 10,
        bytesTransferred: Int64 = 0,
        totalBytes: Int64 = 1000,
        speed: Double = 0,
        eta: TimeInterval = 0
    ) -> OperationProgress {
        OperationProgress(
            currentFile: currentFile,
            filesProcessed: filesProcessed,
            totalFiles: totalFiles,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
            speed: speed,
            eta: eta
        )
    }


    @Test("consume applies each progress snapshot as it arrives, ending on the last one")
    func consumeAppliesEachSnapshot() async {
        let viewModel = ProgressDialogViewModel()
        let (stream, continuation) = AsyncStream<OperationProgress>.makeStream()

        let consumeTask = Task { await viewModel.consume(stream) }

        continuation.yield(progress(currentFile: "a.txt", filesProcessed: 1, bytesTransferred: 100, speed: 10, eta: 90))
        try? await Task.sleep(nanoseconds: 5_000_000)
        #expect(viewModel.currentFile == "a.txt")
        #expect(viewModel.filesProcessed == 1)
        #expect(viewModel.bytesTransferred == 100)

        continuation.yield(progress(currentFile: "b.txt", filesProcessed: 2, bytesTransferred: 500, speed: 20, eta: 25))
        continuation.finish()
        await consumeTask.value

        #expect(viewModel.currentFile == "b.txt")
        #expect(viewModel.filesProcessed == 2)
        #expect(viewModel.totalFiles == 10)
        #expect(viewModel.bytesTransferred == 500)
        #expect(viewModel.totalBytes == 1000)
        #expect(viewModel.speed == 20)
        #expect(viewModel.eta == 25)
    }


    @Test("consume marks isCompleted once the stream finishes")
    func consumeMarksCompletedOnFinish() async {
        let viewModel = ProgressDialogViewModel()
        let (stream, continuation) = AsyncStream<OperationProgress>.makeStream()

        #expect(viewModel.isCompleted == false)
        let consumeTask = Task { await viewModel.consume(stream) }
        continuation.finish()
        await consumeTask.value

        #expect(viewModel.isCompleted)
    }


    @Test("cancel marks isCancelled and propagates to the running operation via onCancel")
    func cancelPropagatesToRunningOperation() {
        final class Recorder { var cancelCallCount = 0 }
        let recorder = Recorder()
        let viewModel = ProgressDialogViewModel(onCancel: { recorder.cancelCallCount += 1 })

        viewModel.cancel()

        #expect(viewModel.isCancelled)
        #expect(recorder.cancelCallCount == 1)
    }
}
