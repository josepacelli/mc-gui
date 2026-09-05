using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Tests.ViewModels;

public class PanelEntryRowTests
{
    private static FileEntry Entry(string name, string fullPath, bool isDirectory, long size = 10) =>
        new(name, fullPath, isDirectory, size, DateTimeOffset.UnixEpoch, IsSymlink: false, IsHidden: false);

    [Fact]
    public void SizeText_ForDirectoryEntry_IsEmpty()
    {
        var row = new PanelEntryRow(Entry("sub", "/panel/sub", isDirectory: true, size: 0), IsMarked: false);

        Assert.Equal(string.Empty, row.SizeText);
    }

    [Fact]
    public void SizeText_ForDotDotEntry_IsEmpty()
    {
        var row = new PanelEntryRow(Entry("..", "/panel", isDirectory: true, size: 0), IsMarked: false);

        Assert.True(row.IsDotDot);
        Assert.True(row.IsFolder);
        Assert.Equal(string.Empty, row.SizeText);
    }

    [Fact]
    public void SizeText_ForFileEntry_IsFormatted()
    {
        var row = new PanelEntryRow(Entry("a.txt", "/panel/a.txt", isDirectory: false, size: 1536), IsMarked: false);

        Assert.True(row.IsFile);
        Assert.False(row.IsFolder);
        Assert.Equal("1.5 kB", row.SizeText);
    }
}
