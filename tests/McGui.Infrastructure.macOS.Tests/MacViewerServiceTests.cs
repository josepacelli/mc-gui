using System.Runtime.Versioning;
using System.Text;
using McGui.Core.Models;
using McGui.Infrastructure.macOS;
using static McGui.Infrastructure.macOS.Tests.TempDirectoryFixture;

namespace McGui.Infrastructure.macOS.Tests;

[SupportedOSPlatform("macos")]
public class MacViewerServiceTests : IDisposable
{
    private readonly TempDirectoryFixture _temp = new("mcgui-viewer-");
    private readonly MacViewerService _sut = new();

    public void Dispose() => _temp.Dispose();

    [Fact]
    public async Task LoadFileAsync_EmptyFile_ReturnsEmptyContent()
    {
        var filePath = WriteFile(_temp.NewSubdir("empty"), "empty.txt", string.Empty);

        var content = await _sut.LoadFileAsync(filePath, CancellationToken.None);

        Assert.Equal(string.Empty, content.Text);
        Assert.Null(content.Bytes);
        Assert.Equal(0, content.FileSize);
        Assert.False(content.IsBinary);
    }

    [Fact]
    public async Task LoadFileAsync_TextFile_ReturnsTextContent()
    {
        var dir = _temp.NewSubdir("text");
        var filePath = WriteFile(dir, "test.txt", "Hello\nWorld\nLine 3");

        var content = await _sut.LoadFileAsync(filePath, CancellationToken.None);

        Assert.Equal("Hello\nWorld\nLine 3", content.Text);
        Assert.Null(content.Bytes);
        Assert.Equal(18, content.FileSize);
        Assert.Equal("UTF-8", content.Encoding);
        Assert.False(content.IsBinary);
    }

    [Fact]
    public async Task LoadFileAsync_BinaryFile_ReturnsBinaryContent()
    {
        var dir = _temp.NewSubdir("binary");
        var filePath = Path.Combine(dir, "test.bin");
        var bytes = new byte[] { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05 };
        await File.WriteAllBytesAsync(filePath, bytes);

        var content = await _sut.LoadFileAsync(filePath, CancellationToken.None);

        Assert.True(content.IsBinary);
        Assert.Equal(bytes, content.Bytes);
        Assert.Equal(bytes.Length, content.FileSize);
        Assert.Equal("binary", content.Encoding);
    }

    [Fact]
    public async Task LoadFileAsync_Utf8WithSpecialChars_DecodesCorrectly()
    {
        var dir = _temp.NewSubdir("utf8");
        var filePath = WriteFile(dir, "utf8.txt", "Hello 世界 🎉 café");

        var content = await _sut.LoadFileAsync(filePath, CancellationToken.None);

        Assert.Equal("Hello 世界 🎉 café", content.Text);
        Assert.Equal("UTF-8", content.Encoding);
    }

    [Fact]
    public async Task LoadFileAsync_Latin1Fallback_Works()
    {
        var dir = _temp.NewSubdir("latin1");
        var filePath = Path.Combine(dir, "latin1.txt");
        // Latin-1 encoded: café = 63 61 66 E9
        var latin1Bytes = Encoding.GetEncoding("Latin1").GetBytes("café");
        await File.WriteAllBytesAsync(filePath, latin1Bytes);

        var content = await _sut.LoadFileAsync(filePath, CancellationToken.None);

        Assert.Equal("café", content.Text);
        Assert.Equal("Latin-1", content.Encoding);
    }

    [Fact]
    public async Task LoadFileChunkAsync_LoadsPartialContent()
    {
        var dir = _temp.NewSubdir("chunk");
        var filePath = WriteFile(dir, "large.txt", new string('A', 1000));

        var content = await _sut.LoadFileChunkAsync(filePath, 0, 100, CancellationToken.None);

        Assert.Equal(new string('A', 100), content.Text);
        Assert.Equal(100, content.FileSize);
    }

    [Fact]
    public async Task LoadFileChunkAsync_OffsetAndLength_Works()
    {
        var dir = _temp.NewSubdir("offset");
        var filePath = WriteFile(dir, "test.txt", "0123456789");

        var content = await _sut.LoadFileChunkAsync(filePath, 3, 4, CancellationToken.None);

        Assert.Equal("3456", content.Text);
    }

    [Fact]
    public void GetFileSize_ReturnsCorrectSize()
    {
        var dir = _temp.NewSubdir("size");
        var filePath = WriteFile(dir, "test.txt", "Hello");

        var size = _sut.GetFileSize(filePath);

        Assert.Equal(5, size);
    }

    [Fact]
    public void GetFileSize_MissingFile_ReturnsZero()
    {
        var size = _sut.GetFileSize("/nonexistent/file.txt");

        Assert.Equal(0, size);
    }

    [Fact]
    public async Task LoadFileAsync_LargeFile_OnlyLoadsFirstChunk()
    {
        var dir = _temp.NewSubdir("large");
        var filePath = Path.Combine(dir, "large.txt");
        var largeContent = new string('X', 15 * 1024 * 1024); // 15MB
        await File.WriteAllTextAsync(filePath, largeContent);

        var content = await _sut.LoadFileAsync(filePath, CancellationToken.None);

        Assert.True(content.FileSize <= 1024 * 1024); // Should be ~1MB chunk
        Assert.Equal("UTF-8", content.Encoding);
    }
}