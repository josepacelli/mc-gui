using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.App.Tests.Fakes;

public sealed class FakePathHistoryStore : IPathHistoryStore
{
    public PanelPathHistory History { get; set; } = new(string.Empty, string.Empty);

    public List<PanelPathHistory> SavedHistories { get; } = [];

    public PanelPathHistory Load() => History;

    public void Save(PanelPathHistory history)
    {
        History = history;
        SavedHistories.Add(history);
    }
}
