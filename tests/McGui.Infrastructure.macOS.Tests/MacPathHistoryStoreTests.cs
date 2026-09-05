using System.Runtime.Versioning;
using McGui.Core.Models;
using McGui.Infrastructure.macOS;

namespace McGui.Infrastructure.macOS.Tests;

[SupportedOSPlatform("macos")]
public class MacPathHistoryStoreTests : IDisposable
{
    private readonly TempDirectoryFixture _temp = new("mcgui-history-");

    public void Dispose() => _temp.Dispose();

    [Fact]
    public void Save_ThenLoad_RestoresBothPersistedPaths()
    {
        var stateFile = Path.Combine(_temp.RootPath, "nested", "state.json");
        var fallbackHome = _temp.NewSubdir("fallback-home");
        var left = _temp.NewSubdir("left-panel-dir");
        var right = _temp.NewSubdir("right-panel-dir");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);

        sut.Save(new PanelPathHistory(left, right));
        var loaded = sut.Load();

        Assert.Equal(left, loaded.LeftPanelPath);
        Assert.Equal(right, loaded.RightPanelPath);
    }

    [Fact]
    public void Save_CreatesParentDirectoriesIfMissing()
    {
        var stateFile = Path.Combine(_temp.RootPath, "a", "b", "c", "state.json");
        var fallbackHome = _temp.NewSubdir("fallback-home-mkdir");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);

        sut.Save(new PanelPathHistory(fallbackHome, fallbackHome));

        Assert.True(File.Exists(stateFile));
    }

    [Fact]
    public void Load_FileDoesNotExist_FallsBackToHomeForBothPanels()
    {
        var stateFile = Path.Combine(_temp.RootPath, "missing-state.json");
        var fallbackHome = _temp.NewSubdir("fallback-home-missing");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);

        var loaded = sut.Load();

        Assert.Equal(fallbackHome, loaded.LeftPanelPath);
        Assert.Equal(fallbackHome, loaded.RightPanelPath);
    }

    [Fact]
    public void Load_PersistedPathNoLongerExists_FallsBackToHomeForThatPanelOnly()
    {
        var stateFile = Path.Combine(_temp.RootPath, "state.json");
        var fallbackHome = _temp.NewSubdir("fallback-home-partial");
        var validRight = _temp.NewSubdir("still-there");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);
        sut.Save(new PanelPathHistory("/no/such/directory/at/all", validRight));

        var loaded = sut.Load();

        Assert.Equal(fallbackHome, loaded.LeftPanelPath);
        Assert.Equal(validRight, loaded.RightPanelPath);
    }

    [Fact]
    public void Load_StateFileContainsInvalidJson_FallsBackToHomeForBothPanels()
    {
        var stateFile = Path.Combine(_temp.RootPath, "corrupt-state.json");
        File.WriteAllText(stateFile, "{ not valid json ");
        var fallbackHome = _temp.NewSubdir("fallback-home-corrupt");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);

        var loaded = sut.Load();

        Assert.Equal(fallbackHome, loaded.LeftPanelPath);
        Assert.Equal(fallbackHome, loaded.RightPanelPath);
    }
}
