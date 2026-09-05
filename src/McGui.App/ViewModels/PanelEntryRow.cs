using McGui.Core.Models;

namespace McGui.App.ViewModels;

public sealed record PanelEntryRow(FileEntry Entry, bool IsMarked)
{
    public string DisplayName => Entry.IsDirectory ? Entry.Name + "/" : Entry.Name;

    public bool IsFolder => Entry.IsDirectory;

    public bool IsFile => !Entry.IsDirectory;

    public bool IsDotDot => Entry.Name == "..";

    public string SizeText => IsFolder ? string.Empty : FileSizeFormatter.Format(Entry.SizeBytes);
}
