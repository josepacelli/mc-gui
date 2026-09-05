using McGui.Core.Models;

namespace McGui.App.ViewModels;

public sealed record PanelEntryRow(FileEntry Entry, bool IsMarked)
{
    public string DisplayName => Entry.IsDirectory ? Entry.Name + "/" : Entry.Name;
}
