import Foundation
import Testing
@testable import MCGuiCore

@Suite("OperationMode, CopyMoveOptions, CopyMovePlan, OperationProgress, OperationResult")
struct OperationsTests {

    @Test("OperationMode round-trips through Codable for each case", arguments: OperationMode.allCases)
    func operationModeCodableRoundTrip(mode: OperationMode) throws {
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(OperationMode.self, from: data)

        #expect(decoded == mode)
    }

    @Test("CopyMoveOptions round-trips through Codable and exposes its three fields")
    func copyMoveOptionsCodableRoundTrip() throws {
        let original = CopyMoveOptions(preserveAttributes: true, followSymlinks: false, updateOnly: true)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CopyMoveOptions.self, from: data)

        #expect(decoded == original)
        #expect(decoded.preserveAttributes == true)
        #expect(decoded.followSymlinks == false)
        #expect(decoded.updateOnly == true)
    }

    @Test("CopyMovePlan round-trips through Codable")
    func copyMovePlanCodableRoundTrip() throws {
        let entry = FileEntry(
            name: "a.txt",
            path: URL(fileURLWithPath: "/tmp/a.txt"),
            size: 1,
            creationDate: Date(timeIntervalSince1970: 0),
            modificationDate: Date(timeIntervalSince1970: 0),
            permissions: [.ownerRead],
            type: .file,
            isHidden: false,
            isSymlink: false,
            symlinkTarget: nil
        )
        let original = CopyMovePlan(
            sources: [entry],
            destinationDirectory: URL(fileURLWithPath: "/tmp/dest"),
            mode: .copy,
            options: CopyMoveOptions(preserveAttributes: true, followSymlinks: true, updateOnly: false)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CopyMovePlan.self, from: data)

        #expect(decoded.sources == original.sources)
        #expect(decoded.destinationDirectory == original.destinationDirectory)
        #expect(decoded.mode == original.mode)
        #expect(decoded.options == original.options)
    }

    @Test("OperationProgress round-trips through Codable")
    func operationProgressCodableRoundTrip() throws {
        let original = OperationProgress(
            currentFile: "big.zip",
            totalFiles: 10,
            bytesTransferred: 1_000,
            totalBytes: 10_000,
            speed: 512.5,
            eta: 30.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OperationProgress.self, from: data)

        #expect(decoded == original)
    }

    @Test("OperationResult round-trips through Codable and exposes its four fields")
    func operationResultCodableRoundTrip() throws {
        let original = OperationResult(
            success: false,
            errorMessage: "disk full",
            processedCount: 3,
            failedItems: [FailedItem(path: "/tmp/big.zip", reason: "disk full")]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OperationResult.self, from: data)

        #expect(decoded == original)
        #expect(decoded.success == false)
        #expect(decoded.errorMessage == "disk full")
        #expect(decoded.processedCount == 3)
        #expect(decoded.failedItems == [FailedItem(path: "/tmp/big.zip", reason: "disk full")])
    }
}
