namespace McGui.Core.Models;

/// <summary>
/// A resolved set of source entries (already expanded recursively for directories)
/// to copy or move into a destination directory.
/// </summary>
public sealed record CopyMovePlan(
    IReadOnlyList<FileEntry> Sources,
    string DestinationDirectory,
    OperationMode Mode);
