namespace McGui.Core.Models;

public sealed record ViewerContent(
    string Text,
    byte[]? Bytes,
    long FileSize,
    string Encoding,
    bool IsBinary
);