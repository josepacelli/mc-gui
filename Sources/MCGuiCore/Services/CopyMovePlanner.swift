import Foundation

public enum CopyMovePlanner {

    public static func conflicts(for sources: [FileEntry], in destinationEntries: [FileEntry]) -> [FileEntry] {
        let destinationNames = Set(destinationEntries.map(\.name))
        return sources.filter { destinationNames.contains($0.name) }
    }

    public static func resolvedName(for name: String, existingNames: Set<String>, maxAttempts: Int = 9_999) -> String? {
        let (stem, ext) = splitStemAndExtension(name)

        for suffix in 1...maxAttempts {
            let candidate = ext.isEmpty ? "\(stem) (\(suffix))" : "\(stem) (\(suffix)).\(ext)"
            if !existingNames.contains(candidate) {
                return candidate
            }
        }

        return nil
    }

    private static func splitStemAndExtension(_ name: String) -> (stem: String, ext: String) {
        guard let dotIndex = name.lastIndex(of: "."), dotIndex != name.startIndex else {
            return (name, "")
        }

        let stem = String(name[name.startIndex..<dotIndex])
        let ext = String(name[name.index(after: dotIndex)...])
        return (stem, ext)
    }
}
