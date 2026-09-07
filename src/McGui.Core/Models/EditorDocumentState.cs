namespace McGui.Core.Models;

public sealed record EditorDocumentState(
    string FilePath,
    string Text,
    string Encoding,
    bool IsReadOnly,
    bool IsLarge
);