import Foundation

/// Expands `%f`/`%d`/`%D` macros in a User Menu (F2) command and runs it via `/bin/sh -c`.
/// Scoped down from the original mc's 9 macros to the 3 most useful: `%f` (current file),
/// `%d` (active panel directory), `%D` (other panel directory).
public enum UserMenuRunner {

    /// Substitutes `%f`/`%d`/`%D` in `command` for `currentFile`/`currentDir`/`otherDir`
    /// (each quoted, since paths may contain spaces). A single left-to-right scan, so a
    /// substituted path that happens to contain a literal "%d"/"%D"/"%f" is never
    /// re-scanned and re-substituted. A bare `%` not followed by one of `f`/`d`/`D` is
    /// passed through unchanged.
    static func expand(_ command: String, currentFile: URL?, currentDir: URL, otherDir: URL) -> String {
        var result = ""
        var rest = Substring(command)

        while let percentIndex = rest.firstIndex(of: "%") {
            result += rest[rest.startIndex..<percentIndex]
            let markerIndex = rest.index(after: percentIndex)
            guard markerIndex < rest.endIndex else {
                result += "%"
                rest = rest[markerIndex...]
                break
            }

            switch rest[markerIndex] {
            case "f":
                result += currentFile.map { "\"\($0.path)\"" } ?? ""
            case "d":
                result += "\"\(currentDir.path)\""
            case "D":
                result += "\"\(otherDir.path)\""
            default:
                result += "%\(rest[markerIndex])"
            }
            rest = rest[rest.index(after: markerIndex)...]
        }
        result += rest

        return result
    }

    /// Runs `command` (after macro expansion) via `/bin/sh -c`, with `currentDir` as the
    /// working directory, capturing combined stdout+stderr and the exit code.
    public static func run(
        command: String,
        currentFile: URL?,
        currentDir: URL,
        otherDir: URL
    ) async -> (output: String, exitCode: Int32) {
        let expanded = expand(command, currentFile: currentFile, currentDir: currentDir, otherDir: otherDir)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", expanded]
        process.currentDirectoryURL = currentDir

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { finished in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (output, finished.terminationStatus))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: ("Failed to launch: \(error.localizedDescription)", -1))
            }
        }
    }
}
