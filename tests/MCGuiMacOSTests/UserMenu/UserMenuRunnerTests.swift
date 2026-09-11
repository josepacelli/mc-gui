import Foundation
import Testing
@testable import MCGuiMacOS

@Suite("UserMenuRunner")
struct UserMenuRunnerTests {

    private let currentFile = URL(fileURLWithPath: "/tmp/a.txt")
    private let currentDir = URL(fileURLWithPath: "/tmp/left")
    private let otherDir = URL(fileURLWithPath: "/tmp/right")


    @Test("%f expands to the quoted current file path")
    func expandsCurrentFile() {
        let result = UserMenuRunner.expand("cat %f", currentFile: currentFile, currentDir: currentDir, otherDir: otherDir)

        #expect(result == "cat \"/tmp/a.txt\"")
    }

    @Test("%f expands to empty when there is no current file")
    func expandsCurrentFileToEmptyWhenNil() {
        let result = UserMenuRunner.expand("cat %f", currentFile: nil, currentDir: currentDir, otherDir: otherDir)

        #expect(result == "cat ")
    }

    @Test("%d expands to the quoted active panel directory")
    func expandsCurrentDir() {
        let result = UserMenuRunner.expand("ls %d", currentFile: currentFile, currentDir: currentDir, otherDir: otherDir)

        #expect(result == "ls \"/tmp/left\"")
    }

    @Test("%D expands to the quoted other panel directory")
    func expandsOtherDir() {
        let result = UserMenuRunner.expand("cp %f %D/", currentFile: currentFile, currentDir: currentDir, otherDir: otherDir)

        #expect(result == "cp \"/tmp/a.txt\" \"/tmp/right\"/")
    }

    @Test("multiple macros in one command all expand correctly, left to right")
    func expandsMultipleMacros() {
        let result = UserMenuRunner.expand("cp %f %D/ && ls %d", currentFile: currentFile, currentDir: currentDir, otherDir: otherDir)

        #expect(result == "cp \"/tmp/a.txt\" \"/tmp/right\"/ && ls \"/tmp/left\"")
    }

    @Test("a substituted path containing a literal %d is not re-substituted")
    func substitutedPathIsNotRescanned() {
        let trickyFile = URL(fileURLWithPath: "/tmp/100%done.txt")
        let result = UserMenuRunner.expand("cat %f", currentFile: trickyFile, currentDir: currentDir, otherDir: otherDir)

        #expect(result == "cat \"/tmp/100%done.txt\"")
    }

    @Test("an unrecognized %-marker passes through unchanged")
    func unrecognizedMarkerPassesThrough() {
        let result = UserMenuRunner.expand("echo 100%x done", currentFile: currentFile, currentDir: currentDir, otherDir: otherDir)

        #expect(result == "echo 100%x done")
    }

    @Test("a trailing bare % passes through unchanged")
    func trailingPercentPassesThrough() {
        let result = UserMenuRunner.expand("echo 100%", currentFile: currentFile, currentDir: currentDir, otherDir: otherDir)

        #expect(result == "echo 100%")
    }

    @Test("a command with no macros is returned unchanged")
    func noMacrosUnchanged() {
        let result = UserMenuRunner.expand("echo hello", currentFile: currentFile, currentDir: currentDir, otherDir: otherDir)

        #expect(result == "echo hello")
    }


    @Test("run captures stdout and a zero exit code on success")
    func runCapturesSuccessfulOutput() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let result = await UserMenuRunner.run(command: "echo hello", currentFile: nil, currentDir: tempDir, otherDir: tempDir)

        #expect(result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
        #expect(result.exitCode == 0)
    }

    @Test("run captures a non-zero exit code on failure")
    func runCapturesFailureExitCode() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let result = await UserMenuRunner.run(command: "exit 7", currentFile: nil, currentDir: tempDir, otherDir: tempDir)

        #expect(result.exitCode == 7)
    }

    @Test("run expands %f in the executed command")
    func runExpandsMacrosBeforeExecuting() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let file = tempDir.appendingPathComponent("usermenu-runner-test-\(UUID().uuidString).txt")
        try Data("marker-content".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let result = await UserMenuRunner.run(command: "cat %f", currentFile: file, currentDir: tempDir, otherDir: tempDir)

        #expect(result.output == "marker-content")
        #expect(result.exitCode == 0)
    }
}
