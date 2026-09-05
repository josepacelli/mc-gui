namespace McGui.Core.Models;

/// <summary>
/// A single file system entry (file, directory, or symlink) listed in a panel.
/// </summary>
public sealed record FileEntry(
    string Name,
    string FullPath,
    bool IsDirectory,
    long SizeBytes,
    DateTimeOffset ModifiedUtc,
    bool IsSymlink,
    bool IsHidden);
