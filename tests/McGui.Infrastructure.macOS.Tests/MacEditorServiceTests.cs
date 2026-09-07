using System.Runtime.Versioning;
using System.Text;
using McGui.Infrastructure.macOS;
using static McGui.Infrastructure.macOS.Tests.TempDirectoryFixture;

namespace McGui.Infrastructure.macOS.Tests;

[SupportedOSPlatform("macos")]
public class MacEditorServiceTests : IDisposable
{
    private readonly TempDirectoryFixture _temp = new("mcgui-editor-");
    private readonly MacEditorService _sut = new();

    public void Dispose() => _temp.Dispose();

    [Fact]
    public async Task LoadAsync_Utf8_ReturnsTextAndEncoding()
    {
        var dir = _temp.NewSubdir("utf8");
        var path = WriteFile(dir, "a.txt", "Hello 世界");

        var state = await _sut.LoadAsync(path, CancellationToken.None);

        Assert.Equal("Hello 世界", state.Text);
        Assert.Equal("UTF-8", state.Encoding);
        Assert.False(state.IsReadOnly);
        Assert.False(state.IsLarge);
    }

    [Fact]
    public async Task LoadAsync_Utf8Bom_StripsBomAndReportsEncoding()
    {
        var dir = _temp.NewSubdir("bom");
        var path = Path.Combine(dir, "bom.txt");
        await File.WriteAllBytesAsync(path, [0xEF, 0xBB, 0xBF, .. Encoding.UTF8.GetBytes("olá")]);

        var state = await _sut.LoadAsync(path, CancellationToken.None);

        Assert.Equal("olá", state.Text);
        Assert.Equal("UTF-8 BOM", state.Encoding);
    }

    [Fact]
    public async Task LoadAsync_Latin1Fallback_DecodesCorrectly()
    {
        var dir = _temp.NewSubdir("latin1");
        var path = Path.Combine(dir, "l1.txt");
        await File.WriteAllBytesAsync(path, Encoding.GetEncoding("Latin1").GetBytes("café"));

        var state = await _sut.LoadAsync(path, CancellationToken.None);

        Assert.Equal("café", state.Text);
        Assert.Equal("Latin-1", state.Encoding);
    }

    [Fact]
    public async Task LoadAsync_EmptyFile_ReturnsEmptyText()
    {
        var dir = _temp.NewSubdir("empty");
        var path = WriteFile(dir, "e.txt", string.Empty);

        var state = await _sut.LoadAsync(path, CancellationToken.None);

        Assert.Equal(string.Empty, state.Text);
        Assert.Equal("UTF-8", state.Encoding);
    }

    [Fact]
    public async Task SaveAsync_RoundTripsText()
    {
        var dir = _temp.NewSubdir("save");
        var path = Path.Combine(dir, "out.txt");

        await _sut.SaveAsync(path, "conteúdo salvo 123", CancellationToken.None);

        Assert.Equal("conteúdo salvo 123", await File.ReadAllTextAsync(path));
    }

    [Fact]
    public void IsReadOnly_WritableFile_ReturnsFalse()
    {
        var dir = _temp.NewSubdir("ro-false");
        var path = WriteFile(dir, "w.txt", "x");

        Assert.False(_sut.IsReadOnly(path));
    }

    [Fact]
    public void IsReadOnly_WriteRemoved_ReturnsTrue()
    {
        var dir = _temp.NewSubdir("ro-true");
        var path = WriteFile(dir, "ro.txt", "x");
        File.SetUnixFileMode(path, UnixFileMode.UserRead | UnixFileMode.GroupRead | UnixFileMode.OtherRead);

        try
        {
            Assert.True(_sut.IsReadOnly(path));
        }
        finally
        {
            File.SetUnixFileMode(path, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        }
    }

    [Fact]
    public async Task LoadAsync_LargeFile_SetsIsLarge()
    {
        var dir = _temp.NewSubdir("large");
        var path = Path.Combine(dir, "big.txt");
        await File.WriteAllTextAsync(path, new string('x', 60 * 1024 * 1024));

        var state = await _sut.LoadAsync(path, CancellationToken.None);

        Assert.True(state.IsLarge);
    }
}