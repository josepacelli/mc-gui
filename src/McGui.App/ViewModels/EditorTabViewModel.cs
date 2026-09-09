using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using McGui.Core.Interfaces;

namespace McGui.App.ViewModels;

public sealed partial class EditorTabViewModel : ObservableObject
{
    private readonly IEditorService _editorService;
    private string _savedText;

    public EditorTabViewModel(IEditorService editorService, string filePath, string text, string encoding, bool isReadOnly, bool isLarge)
    {
        _editorService = editorService;
        _savedText = text;
        FilePath = filePath;
        DocumentText = text;
        Encoding = encoding;
        IsReadOnly = isReadOnly;
        IsLarge = isLarge;
    }

    public string FilePath { get; set; }

    public string FileName => Path.GetFileName(FilePath);

    public string Encoding { get; }

    public bool IsReadOnly { get; }

    public bool IsLarge { get; }

    [ObservableProperty]
    private string documentText;

    [ObservableProperty]
    private bool isDirty;

    public string Title => IsDirty ? FileName + " *" : FileName;

    partial void OnIsDirtyChanged(bool value) => OnPropertyChanged(nameof(Title));

    partial void OnDocumentTextChanged(string value) => IsDirty = !string.Equals(value, _savedText, System.StringComparison.Ordinal);

    public void MarkSaved()
    {
        _savedText = DocumentText;
        IsDirty = false;
    }

    public async Task SaveAsync(System.Threading.CancellationToken ct)
    {
        await _editorService.SaveAsync(FilePath, DocumentText, ct);
        MarkSaved();
    }

    public async Task SaveAsAsync(string newFilePath, System.Threading.CancellationToken ct)
    {
        await _editorService.SaveAsync(newFilePath, DocumentText, ct);
        FilePath = newFilePath;
        MarkSaved();
        OnPropertyChanged(nameof(Title));
    }
}