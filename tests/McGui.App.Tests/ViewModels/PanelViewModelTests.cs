using McGui.App.Tests.Fakes;
using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Tests.ViewModels;

public class PanelViewModelTests
{
    private static FileEntry File(string name, string parent) =>
        new(name, Path.Combine(parent, name), IsDirectory: false, SizeBytes: 10, DateTimeOffset.UnixEpoch, IsSymlink: false, IsHidden: false);

    private static FileEntry Dir(string name, string parent) =>
        new(name, Path.Combine(parent, name), IsDirectory: true, SizeBytes: 0, DateTimeOffset.UnixEpoch, IsSymlink: false, IsHidden: false);

    [Fact]
    public void Constructor_PersistedDirectoryExists_UsesItAsInitialState()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left", File("a.txt", "/left"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };

        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home");

        Assert.Equal("/left", vm.CurrentDirectory);
        Assert.Single(vm.Entries);
    }

    [Fact]
    public void Constructor_PersistedDirectoryMissing_FallsBackToHomeDirectory()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/home", File("readme.txt", "/home"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/does/not/exist", "/right") };

        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home");

        Assert.Equal("/home", vm.CurrentDirectory);
    }

    [Fact]
    public async Task NavigateToAsync_Subdirectory_UpdatesCurrentDirectoryAndEntries()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/root", Dir("sub", "/root"));
        fs.AddDirectory("/root/sub", File("nested.txt", "/root/sub"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/root", "/root") };
        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home");

        await vm.NavigateToAsync("/root/sub");

        Assert.Equal("/root/sub", vm.CurrentDirectory);
        Assert.Single(vm.Entries);
        Assert.Equal("nested.txt", vm.Entries[0].Name);
    }

    [Fact]
    public async Task NavigateToParentAsync_MovesToParentDirectory()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/root", Dir("sub", "/root"));
        fs.AddDirectory("/root/sub", File("nested.txt", "/root/sub"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/root/sub", "/root/sub") };
        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home");

        await vm.NavigateToParentAsync();

        Assert.Equal("/root", vm.CurrentDirectory);
    }

    [Fact]
    public async Task ActivateCursorEntryAsync_OnDirectoryEntry_NavigatesIntoIt()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/root", Dir("sub", "/root"));
        fs.AddDirectory("/root/sub", File("nested.txt", "/root/sub"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/root", "/root") };
        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home");

        await vm.ActivateCursorEntryAsync();

        Assert.Equal("/root/sub", vm.CurrentDirectory);
    }

    [Fact]
    public void MoveCursorDown_AtLastEntry_DoesNotExceedBounds()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/root", File("a.txt", "/root"), File("b.txt", "/root"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/root", "/root") };
        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home");

        vm.MoveCursorDown();
        vm.MoveCursorDown();
        vm.MoveCursorDown();

        Assert.Equal(1, vm.CursorIndex);
    }

    [Fact]
    public void MoveCursorUp_AtFirstEntry_DoesNotGoBelowZero()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/root", File("a.txt", "/root"), File("b.txt", "/root"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/root", "/root") };
        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home");

        vm.MoveCursorUp();

        Assert.Equal(0, vm.CursorIndex);
    }

    [Fact]
    public async Task NavigateToAsync_SlowListing_ShowsLoadingIndicatorWhilePending()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/root", File("a.txt", "/root"));
        fs.AddDirectory("/slow", File("b.txt", "/slow"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/root", "/root") };
        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home", loadingIndicatorDelay: TimeSpan.FromMilliseconds(20));
        fs.Delay = TimeSpan.FromMilliseconds(150);

        var navigateTask = vm.NavigateToAsync("/slow");
        await Task.Delay(60);

        Assert.True(vm.IsLoading);

        await navigateTask;

        Assert.False(vm.IsLoading);
    }

    [Fact]
    public async Task NavigateToAsync_FastListing_NeverShowsLoadingIndicator()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/root", File("a.txt", "/root"));
        fs.AddDirectory("/fast", File("b.txt", "/fast"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/root", "/root") };
        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home", loadingIndicatorDelay: TimeSpan.FromMilliseconds(200));
        fs.Delay = TimeSpan.Zero;
        var sawLoadingTrue = false;
        vm.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(PanelViewModel.IsLoading) && vm.IsLoading)
            {
                sawLoadingTrue = true;
            }
        };

        await vm.NavigateToAsync("/fast");

        Assert.False(sawLoadingTrue);
    }

    [Fact]
    public void PersistCurrentDirectory_SavesCurrentPathForItsSideOnly()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left-new", File("a.txt", "/left-new"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left-new", "/right-original") };
        var vm = new PanelViewModel(fs, history, PanelSide.Left, fallbackHomeDirectory: "/home");

        vm.PersistCurrentDirectory();

        var saved = Assert.Single(history.SavedHistories);
        Assert.Equal("/left-new", saved.LeftPanelPath);
        Assert.Equal("/right-original", saved.RightPanelPath);
    }
}
