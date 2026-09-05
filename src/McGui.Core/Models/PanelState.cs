namespace McGui.Core.Models;

public sealed class PanelState
{
    public string CurrentDirectory { get; set; } = "";
    public IReadOnlyList<FileEntry> Entries { get; set; } = Array.Empty<FileEntry>();
    public int CursorIndex { get; set; }
    public HashSet<string> MarkedPaths { get; } = new();
    public PanelSortColumn SortColumn { get; set; } = PanelSortColumn.Name;
    public bool SortDescending { get; set; }
    public bool ShowHidden { get; set; }
    public string? FilterText { get; set; } // DPC-33
}
