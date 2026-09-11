import Foundation

public enum UserMenuRunner {

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
