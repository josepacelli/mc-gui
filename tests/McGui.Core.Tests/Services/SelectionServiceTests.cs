using McGui.Core.Models;
using McGui.Core.Services;

namespace McGui.Core.Tests.Services;

public class SelectionServiceTests
{
    private static FileEntry Entry(string name, long size = 0) =>
        new(name, $"/panel/{name}", IsDirectory: false, SizeBytes: size, ModifiedUtc: DateTimeOffset.UnixEpoch, IsSymlink: false, IsHidden: false);

    private static PanelState StateWith(params FileEntry[] entries)
    {
        return new PanelState
        {
            CurrentDirectory = "/panel",
            Entries = entries,
            CursorIndex = 0,
        };
    }

    [Fact]
    public void Toggle_MarksEntryAndAdvancesCursor()
    {
        var state = StateWith(Entry("a.txt"), Entry("b.txt"), Entry("c.txt"));

        SelectionService.Toggle(state, 0);

        Assert.Contains("/panel/a.txt", state.MarkedPaths);
        Assert.Equal(1, state.CursorIndex);
    }

    [Fact]
    public void Toggle_OnAlreadyMarkedEntry_Unmarks()
    {
        var state = StateWith(Entry("a.txt"), Entry("b.txt"));
        SelectionService.Toggle(state, 0);

        SelectionService.Toggle(state, 0);

        Assert.DoesNotContain("/panel/a.txt", state.MarkedPaths);
    }

    [Fact]
    public void Toggle_OnLastEntry_CursorDoesNotExceedBounds()
    {
        var state = StateWith(Entry("a.txt"), Entry("b.txt"));

        SelectionService.Toggle(state, 1);

        Assert.Equal(1, state.CursorIndex);
    }

    [Fact]
    public void MarkByPattern_MarksAllMatchingEntries()
    {
        var state = StateWith(Entry("report.txt"), Entry("notes.txt"), Entry("image.png"));

        SelectionService.MarkByPattern(state, "*.txt");

        Assert.Contains("/panel/report.txt", state.MarkedPaths);
        Assert.Contains("/panel/notes.txt", state.MarkedPaths);
        Assert.DoesNotContain("/panel/image.png", state.MarkedPaths);
    }

    [Fact]
    public void MarkByPattern_NoMatch_MarksNothing()
    {
        var state = StateWith(Entry("report.txt"), Entry("notes.txt"));

        SelectionService.MarkByPattern(state, "*.png");

        Assert.Empty(state.MarkedPaths);
    }

    [Fact]
    public void UnmarkByPattern_UnmarksOnlyMatchingEntries()
    {
        var state = StateWith(Entry("report.txt"), Entry("notes.txt"), Entry("image.png"));
        SelectionService.MarkByPattern(state, "*");

        SelectionService.UnmarkByPattern(state, "*.txt");

        Assert.DoesNotContain("/panel/report.txt", state.MarkedPaths);
        Assert.DoesNotContain("/panel/notes.txt", state.MarkedPaths);
        Assert.Contains("/panel/image.png", state.MarkedPaths);
    }

    [Fact]
    public void Invert_FlipsMarkedStateOfEveryEntry()
    {
        var state = StateWith(Entry("a.txt"), Entry("b.txt"), Entry("c.txt"));
        SelectionService.Toggle(state, 0);

        SelectionService.Invert(state);

        Assert.DoesNotContain("/panel/a.txt", state.MarkedPaths);
        Assert.Contains("/panel/b.txt", state.MarkedPaths);
        Assert.Contains("/panel/c.txt", state.MarkedPaths);
    }

    [Fact]
    public void MarkedEntries_CountAndTotalSize_AreComputableFromResultingState()
    {
        var state = StateWith(Entry("a.txt", size: 100), Entry("b.txt", size: 250), Entry("c.txt", size: 10));
        SelectionService.MarkByPattern(state, "*.txt");
        SelectionService.Toggle(state, 2);

        var marked = state.Entries.Where(e => state.MarkedPaths.Contains(e.FullPath)).ToList();

        Assert.Equal(2, marked.Count);
        Assert.Equal(350, marked.Sum(e => e.SizeBytes));
    }
}
