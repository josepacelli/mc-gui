namespace McGui.Core.Models;

public sealed record OperationResult(
    bool Succeeded,
    IReadOnlyList<(string Path, string Reason)> SkippedEntries);
