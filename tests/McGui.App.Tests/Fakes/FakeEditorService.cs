using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.App.Tests.Fakes;

public sealed class FakeEditorService : IEditorService
{
    private readonly Dictionary<string, string> _files = new(StringComparer.Ordinal);

    public void AddFile(string path, string content) => _files[path] = content;

    public Task<EditorDocumentState> LoadAsync(string filePath, CancellationToken ct)
    {
        var content = _files.TryGetValue(filePath, out var text) ? text : string.Empty;
        return Task.FromResult(new EditorDocumentState(filePath, content, "UTF-8", false, false));
    }

    public Task SaveAsync(string filePath, string text, CancellationToken ct)
    {
        _files[filePath] = text;
        return Task.CompletedTask;
    }

    public bool IsReadOnly(string filePath) => false;
}