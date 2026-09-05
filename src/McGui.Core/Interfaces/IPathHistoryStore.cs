using McGui.Core.Models;

namespace McGui.Core.Interfaces;

public interface IPathHistoryStore
{
    PanelPathHistory Load();

    void Save(PanelPathHistory history);
}
