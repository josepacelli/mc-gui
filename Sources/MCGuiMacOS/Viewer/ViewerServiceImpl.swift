import Foundation
import AppKit
import MCGuiCore

public enum ViewerServiceError: Error, Equatable {
    case cannotRead(URL)
    case noNavigationContext
}

public final class ViewerServiceImpl {
    private let chunkSize: Int
    private let binaryDetectionSampleSize: Int
    private let openForReading: (URL) throws -> FileHandle
    private let readChunk: (FileHandle, Int) -> Data


    private var fileList: [URL] = []
    private var currentIndex: Int?
    private var currentText: String?

    public init(
        chunkSize: Int = 1_048_576,
        binaryDetectionSampleSize: Int = 8192,
        openForReading: ((URL) throws -> FileHandle)? = nil,
        readChunk: ((FileHandle, Int) -> Data)? = nil
    ) {
        self.chunkSize = chunkSize
        self.binaryDetectionSampleSize = binaryDetectionSampleSize
        self.openForReading = openForReading ?? { url in try FileHandle(forReadingFrom: url) }
        self.readChunk = readChunk ?? { handle, size in handle.readData(ofLength: size) }
    }


    public func load(_ url: URL) async throws -> ViewerContent {
        let handle: FileHandle
        do {
            handle = try openForReading(url)
        } catch {
            throw ViewerServiceError.cannotRead(url)
        }
        defer { try? handle.close() }

        let data = try await readAllChunked(handle)
        currentIndex = fileList.firstIndex(of: url)

        if data.isEmpty {
            currentText = ""
            return .text("")
        }

        if NSImage(data: data) != nil {
            currentText = nil
            return .image(data)
        }

        if Self.isBinary(data.prefix(binaryDetectionSampleSize)) {
            currentText = nil
            return .hexData(data)
        }

        if let text = String(data: data, encoding: .utf8) {
            currentText = text
            return .text(text)
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            currentText = text
            return .text(text)
        }
        currentText = nil
        return .hexData(data)
    }


    public func setFileList(_ urls: [URL]) {
        fileList = urls
    }

    public func nextFile() async throws -> ViewerContent {
        try await move(by: 1)
    }

    public func previousFile() async throws -> ViewerContent {
        try await move(by: -1)
    }

    private func move(by delta: Int) async throws -> ViewerContent {
        guard let index = currentIndex else {
            throw ViewerServiceError.noNavigationContext
        }
        let targetIndex = fileList.indices.contains(index + delta) ? index + delta : index
        return try await load(fileList[targetIndex])
    }


    public func search(_ query: String) -> [SearchMatch] {
        guard let text = currentText, !query.isEmpty else { return [] }

        let haystack = text as NSString
        var matches: [SearchMatch] = []
        var searchRange = NSRange(location: 0, length: haystack.length)

        while searchRange.length > 0 {
            let found = haystack.range(of: query, options: .caseInsensitive, range: searchRange)
            guard found.location != NSNotFound else { break }
            matches.append(SearchMatch(location: found.location, length: found.length))
            let nextLocation = found.location + found.length
            searchRange = NSRange(location: nextLocation, length: haystack.length - nextLocation)
        }

        return matches
    }

    private func readAllChunked(_ handle: FileHandle) async throws -> Data {
        var result = Data()
        while true {
            let chunk = readChunk(handle, chunkSize)
            if chunk.isEmpty { break }
            result.append(chunk)
            await Task.yield()
        }
        return result
    }

    static func isBinary<D: DataProtocol>(_ sample: D) -> Bool {
        sample.contains(0)
    }
}

extension ViewerServiceImpl: ViewerService {}
