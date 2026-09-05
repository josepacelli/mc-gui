namespace McGui.Core.Models;

public sealed record FileEntry(
    string Name,
    string FullPath,
    bool IsDirectory,
    long SizeBytes,
    DateTimeOffset ModifiedUtc,
    bool IsSymlink,
    bool IsHidden);
