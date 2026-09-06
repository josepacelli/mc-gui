namespace McGui.Core.Models;

public sealed record ViewerState(
    string FilePath,
    ViewerMode Mode,
    long ScrollOffset,
    bool WordWrap,
    string? SearchQuery,
    long SearchMatchIndex
);