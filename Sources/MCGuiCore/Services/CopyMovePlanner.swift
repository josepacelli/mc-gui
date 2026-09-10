import Foundation

/// Pure conflict-detection and rename-suffixing logic for copy/move operations.
///
/// Does not touch the filesystem: callers supply the destination directory's current
/// entries (or existing names) so this stays platform-agnostic and testable without a
/// real filesystem. The macOS `FileSystemServiceImpl` (T13) uses this to decide, for
/// each source, whether it collides with something already at the destination and, when
/// the user picks Rename, what name to use instead.
public enum CopyMovePlanner {

    /// The sources that collide with an entry already present at the destination
    /// (matched by file name), i.e. `FO-05`'s "destination file exists" condition.
    public static func conflicts(for sources: [FileEntry], in destinationEntries: [FileEntry]) -> [FileEntry] {
        let destinationNames = Set(destinationEntries.map(\.name))
        return sources.filter { destinationNames.contains($0.name) }
    }

    /// Produces the next available numeric-suffixed name for `name` per `FO-08`
    /// ("file (1).txt", "file (2).txt", ...), skipping any name already present in
    /// `existingNames`. Tries suffixes `1...maxAttempts` and returns `nil` if every one
    /// of them collides (exhausted-suffix-search edge case).
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
