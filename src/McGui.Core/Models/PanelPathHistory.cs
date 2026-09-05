namespace McGui.Core.Models;

/// <summary>
/// Last-used directory for each of the two panels, persisted across app launches.
/// </summary>
public sealed record PanelPathHistory(string LeftPanelPath, string RightPanelPath);
