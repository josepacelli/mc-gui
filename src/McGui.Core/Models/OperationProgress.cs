namespace McGui.Core.Models;

/// <summary>
/// Point-in-time progress snapshot of a running copy/move operation.
/// </summary>
public sealed record OperationProgress(
    string CurrentFileName,
    int FilesDone,
    int FilesTotal,
    long BytesDone,
    long BytesTotal,
    bool IsCancelled);
