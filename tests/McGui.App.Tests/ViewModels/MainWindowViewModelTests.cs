using McGui.App.Tests.Fakes;
using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Tests.ViewModels;

public class MainWindowViewModelTests
{
    private static (FakeFileSystemService FileSystem, FakePathHistoryStore History) BuildDependencies()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left", new FileEntry("a.txt", "/left/a.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        fs.AddDirectory("/right", new FileEntry("b.txt", "/right/b.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        return (fs, history);
    }

    [Fact]
    public void Constructor_LeftPanelIsActiveByDefault()
    {
        var (fs, history) = BuildDependencies();

        var vm = new MainWindowViewModel(fs, history);

        Assert.Same(vm.LeftPanel, vm.ActivePanel);
        Assert.True(vm.LeftPanel.IsActive);
        Assert.False(vm.RightPanel.IsActive);
    }

    [Fact]
    public void SwitchActivePanel_TogglesFromLeftToRight()
    {
        var (fs, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, history);

        vm.SwitchActivePanel();

        Assert.Same(vm.RightPanel, vm.ActivePanel);
        Assert.True(vm.RightPanel.IsActive);
        Assert.False(vm.LeftPanel.IsActive);
    }

    [Fact]
    public void SwitchActivePanel_CalledTwice_ReturnsToLeftPanel()
    {
        var (fs, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, history);

        vm.SwitchActivePanel();
        vm.SwitchActivePanel();

        Assert.Same(vm.LeftPanel, vm.ActivePanel);
        Assert.True(vm.LeftPanel.IsActive);
        Assert.False(vm.RightPanel.IsActive);
    }

    [Fact]
    public void RequestCopy_WithCursorEntry_PrefillsOppositePanelAsDestination()
    {
        var (fs, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, history);
        CopyMoveDialogViewModel? requested = null;
        vm.CopyMoveRequested += (_, dialog) => requested = dialog;

        vm.RequestCopy();

        Assert.NotNull(requested);
        Assert.Equal(OperationMode.Copy, requested!.Mode);
        Assert.Equal("/right", requested.DestinationDirectory);
        Assert.Single(requested.Sources);
        Assert.Equal("/left/a.txt", requested.Sources[0].FullPath);
    }

    [Fact]
    public void RequestMove_SingleMarkedEntry_PrefillsSourceOwnDirectoryToEnableRename()
    {
        var (fs, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, history);
        vm.ActivePanel.ToggleMark(0);
        CopyMoveDialogViewModel? requested = null;
        vm.CopyMoveRequested += (_, dialog) => requested = dialog;

        vm.RequestMove();

        Assert.NotNull(requested);
        Assert.Equal(OperationMode.Move, requested!.Mode);
        Assert.Equal("/left", requested.DestinationDirectory);
        Assert.True(requested.CanRename);
    }

    [Fact]
    public void RequestMove_MultipleMarkedEntries_PrefillsOppositePanelAsDestination()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory(
            "/left",
            new FileEntry("a.txt", "/left/a.txt", false, 1, DateTimeOffset.UnixEpoch, false, false),
            new FileEntry("b.txt", "/left/b.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        fs.AddDirectory("/right", new FileEntry("c.txt", "/right/c.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, history);
        vm.ActivePanel.ToggleMark(0);
        vm.ActivePanel.ToggleMark(1);
        CopyMoveDialogViewModel? requested = null;
        vm.CopyMoveRequested += (_, dialog) => requested = dialog;

        vm.RequestMove();

        Assert.NotNull(requested);
        Assert.Equal(2, requested!.Sources.Count);
        Assert.Equal("/right", requested.DestinationDirectory);
        Assert.False(requested.CanRename);
    }

    [Fact]
    public void RequestCopy_NoMarkedEntriesAndNoCursorEntry_DoesNotRaiseCopyMoveRequested()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left");
        fs.AddDirectory("/right");
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, history);
        var raised = false;
        vm.CopyMoveRequested += (_, _) => raised = true;

        vm.RequestCopy();

        Assert.False(raised);
    }
}
