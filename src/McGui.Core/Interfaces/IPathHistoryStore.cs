using McGui.Core.Models;

namespace McGui.Core.Interfaces;

/// <summary>
/// Persists and restores the last-used directory for each panel across app launches.
/// </summary>
public interface IPathHistoryStore
{
    PanelPathHistory Load();

    void Save(PanelPathHistory history);
}
