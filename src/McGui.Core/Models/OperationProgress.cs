namespace McGui.Core.Models;

public sealed record OperationProgress(
    string CurrentFileName,
    int FilesDone,
    int FilesTotal,
    long BytesDone,
    long BytesTotal,
    bool IsCancelled);
