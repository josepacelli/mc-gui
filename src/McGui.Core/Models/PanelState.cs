namespace McGui.Core.Models;

/// <summary>
/// Mutable state of a single dual-pane panel: current directory, listing, cursor,
/// selection and display options.
/// </summary>
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
