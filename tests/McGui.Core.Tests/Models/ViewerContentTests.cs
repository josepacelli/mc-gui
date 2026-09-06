using McGui.Core.Models;

namespace McGui.Core.Tests.Models;

public class ViewerContentTests
{
    [Fact]
    public void Construction_SetsAllProperties()
    {
        var bytes = new byte[] { 0x48, 0x65, 0x6C, 0x6C, 0x6F };
        var content = new ViewerContent("Hello", bytes, 5, "UTF-8", false);

        Assert.Equal("Hello", content.Text);
        Assert.Equal(bytes, content.Bytes);
        Assert.Equal(5, content.FileSize);
        Assert.Equal("UTF-8", content.Encoding);
        Assert.False(content.IsBinary);
    }

    [Fact]
    public void BinaryContent_HasBytesAndIsBinaryTrue()
    {
        var bytes = new byte[] { 0x00, 0x01, 0x02 };
        var content = new ViewerContent(string.Empty, bytes, 3, "binary", true);

        Assert.True(content.IsBinary);
        Assert.Equal(bytes, content.Bytes);
        Assert.Equal(string.Empty, content.Text);
    }

    [Fact]
    public void Equality_Works()
    {
        var c1 = new ViewerContent("Hello", null, 5, "UTF-8", false);
        var c2 = new ViewerContent("Hello", null, 5, "UTF-8", false);
        var c3 = new ViewerContent("World", null, 5, "UTF-8", false);

        Assert.Equal(c1, c2);
        Assert.NotEqual(c1, c3);
    }
}