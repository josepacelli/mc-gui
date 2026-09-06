using McGui.Core.Models;

namespace McGui.Core.Tests.Models;

public class ViewerStateTests
{
    [Fact]
    public void Construction_SetsAllProperties()
    {
        var state = new ViewerState(
            "/path/file.txt",
            ViewerMode.Hex,
            1024,
            true,
            "search",
            5);

        Assert.Equal("/path/file.txt", state.FilePath);
        Assert.Equal(ViewerMode.Hex, state.Mode);
        Assert.Equal(1024, state.ScrollOffset);
        Assert.True(state.WordWrap);
        Assert.Equal("search", state.SearchQuery);
        Assert.Equal(5, state.SearchMatchIndex);
    }

    [Fact]
    public void Equality_Works()
    {
        var s1 = new ViewerState("/a", ViewerMode.Text, 0, false, null, 0);
        var s2 = new ViewerState("/a", ViewerMode.Text, 0, false, null, 0);
        var s3 = new ViewerState("/b", ViewerMode.Text, 0, false, null, 0);

        Assert.Equal(s1, s2);
        Assert.NotEqual(s1, s3);
    }
}