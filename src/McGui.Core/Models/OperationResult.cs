namespace McGui.Core.Models;

/// <summary>
/// Outcome of a completed file operation, including entries that were skipped
/// (e.g. permission errors) rather than causing the whole operation to fail.
/// </summary>
public sealed record OperationResult(
    bool Succeeded,
    IReadOnlyList<(string Path, string Reason)> SkippedEntries);
