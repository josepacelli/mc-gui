using McGui.Core.Models;

namespace McGui.Core.Tests.Models;

public class EditorDocumentStateTests
{
    [Fact]
    public void Construction_SetsAllProperties()
    {
        var state = new EditorDocumentState("/a.txt", "hello", "UTF-8", false, false);

        Assert.Equal("/a.txt", state.FilePath);
        Assert.Equal("hello", state.Text);
        Assert.Equal("UTF-8", state.Encoding);
        Assert.False(state.IsReadOnly);
        Assert.False(state.IsLarge);
    }

    [Fact]
    public void Equality_Works()
    {
        var s1 = new EditorDocumentState("/a", "x", "UTF-8", false, false);
        var s2 = new EditorDocumentState("/a", "x", "UTF-8", false, false);
        var s3 = new EditorDocumentState("/b", "x", "UTF-8", false, false);

        Assert.Equal(s1, s2);
        Assert.NotEqual(s1, s3);
    }
}