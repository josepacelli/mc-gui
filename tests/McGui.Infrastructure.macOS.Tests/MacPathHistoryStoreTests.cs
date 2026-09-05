using McGui.Core.Models;
using McGui.Infrastructure.macOS;

namespace McGui.Infrastructure.macOS.Tests;

public class MacPathHistoryStoreTests : IDisposable
{
    private readonly DirectoryInfo _root = Directory.CreateTempSubdirectory("mcgui-history-");

    public void Dispose()
    {
        try
        {
            _root.Delete(recursive: true);
        }
        catch (IOException)
        {
        }
    }

    private string NewSubdir(string name)
    {
        var path = Path.Combine(_root.FullName, name);
        Directory.CreateDirectory(path);
        return path;
    }

    [Fact]
    public void Save_ThenLoad_RestoresBothPersistedPaths()
    {
        var stateFile = Path.Combine(_root.FullName, "nested", "state.json");
        var fallbackHome = NewSubdir("fallback-home");
        var left = NewSubdir("left-panel-dir");
        var right = NewSubdir("right-panel-dir");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);

        sut.Save(new PanelPathHistory(left, right));
        var loaded = sut.Load();

        Assert.Equal(left, loaded.LeftPanelPath);
        Assert.Equal(right, loaded.RightPanelPath);
    }

    [Fact]
    public void Save_CreatesParentDirectoriesIfMissing()
    {
        var stateFile = Path.Combine(_root.FullName, "a", "b", "c", "state.json");
        var fallbackHome = NewSubdir("fallback-home-mkdir");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);

        sut.Save(new PanelPathHistory(fallbackHome, fallbackHome));

        Assert.True(File.Exists(stateFile));
    }

    [Fact]
    public void Load_FileDoesNotExist_FallsBackToHomeForBothPanels()
    {
        var stateFile = Path.Combine(_root.FullName, "missing-state.json");
        var fallbackHome = NewSubdir("fallback-home-missing");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);

        var loaded = sut.Load();

        Assert.Equal(fallbackHome, loaded.LeftPanelPath);
        Assert.Equal(fallbackHome, loaded.RightPanelPath);
    }

    [Fact]
    public void Load_PersistedPathNoLongerExists_FallsBackToHomeForThatPanelOnly()
    {
        var stateFile = Path.Combine(_root.FullName, "state.json");
        var fallbackHome = NewSubdir("fallback-home-partial");
        var validRight = NewSubdir("still-there");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);
        sut.Save(new PanelPathHistory("/no/such/directory/at/all", validRight));

        var loaded = sut.Load();

        Assert.Equal(fallbackHome, loaded.LeftPanelPath);
        Assert.Equal(validRight, loaded.RightPanelPath);
    }

    [Fact]
    public void Load_StateFileContainsInvalidJson_FallsBackToHomeForBothPanels()
    {
        var stateFile = Path.Combine(_root.FullName, "corrupt-state.json");
        File.WriteAllText(stateFile, "{ not valid json ");
        var fallbackHome = NewSubdir("fallback-home-corrupt");
        var sut = new MacPathHistoryStore(stateFile, fallbackHome);

        var loaded = sut.Load();

        Assert.Equal(fallbackHome, loaded.LeftPanelPath);
        Assert.Equal(fallbackHome, loaded.RightPanelPath);
    }
}
