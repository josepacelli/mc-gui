namespace McGui.Core.Models;

public sealed record CopyMovePlan(
    IReadOnlyList<FileEntry> Sources,
    string DestinationDirectory,
    OperationMode Mode);
