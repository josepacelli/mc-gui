using McGui.Core.Models;

namespace McGui.Core.Interfaces;

public interface IEditorService
{
    Task<EditorDocumentState> LoadAsync(string filePath, CancellationToken ct);

    Task SaveAsync(string filePath, string text, CancellationToken ct);

    bool IsReadOnly(string filePath);
}