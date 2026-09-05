using McGui.App.Tests.Fakes;
using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Tests.ViewModels;

public class MainWindowViewModelTests
{
    private static (FakeFileSystemService FileSystem, FakeTrashService Trash, FakePathHistoryStore History) BuildDependencies()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left", new FileEntry("a.txt", "/left/a.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        fs.AddDirectory("/right", new FileEntry("b.txt", "/right/b.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        return (fs, new FakeTrashService(), history);
    }

    [Fact]
    public void Constructor_LeftPanelIsActiveByDefault()
    {
        var (fs, trash, history) = BuildDependencies();

        var vm = new MainWindowViewModel(fs, trash, history);

        Assert.Same(vm.LeftPanel, vm.ActivePanel);
        Assert.True(vm.LeftPanel.IsActive);
        Assert.False(vm.RightPanel.IsActive);
    }

    [Fact]
    public void SwitchActivePanel_TogglesFromLeftToRight()
    {
        var (fs, trash, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history);

        vm.SwitchActivePanel();

        Assert.Same(vm.RightPanel, vm.ActivePanel);
        Assert.True(vm.RightPanel.IsActive);
        Assert.False(vm.LeftPanel.IsActive);
    }

    [Fact]
    public void SwitchActivePanel_CalledTwice_ReturnsToLeftPanel()
    {
        var (fs, trash, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history);

        vm.SwitchActivePanel();
        vm.SwitchActivePanel();

        Assert.Same(vm.LeftPanel, vm.ActivePanel);
        Assert.True(vm.LeftPanel.IsActive);
        Assert.False(vm.RightPanel.IsActive);
    }

    [Fact]
    public void RequestCopy_WithCursorEntry_PrefillsOppositePanelAsDestination()
    {
        var (fs, trash, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history);
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
        var (fs, trash, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history);
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
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history);
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
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history);
        var raised = false;
        vm.CopyMoveRequested += (_, _) => raised = true;

        vm.RequestCopy();

        Assert.False(raised);
    }

    [Fact]
    public void RequestMove_NoMarkedEntriesAndNoCursorEntry_DoesNotRaiseCopyMoveRequested()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left");
        fs.AddDirectory("/right");
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history);
        var raised = false;
        vm.CopyMoveRequested += (_, _) => raised = true;

        vm.RequestMove();

        Assert.False(raised);
    }

    [Fact]
    public void RequestDelete_WithCursorEntry_RaisesDeleteRequestedWithSelectedEntries()
    {
        var (fs, trash, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history);
        DeleteConfirmDialogViewModel? requested = null;
        vm.DeleteRequested += (_, dialog) => requested = dialog;

        vm.RequestDelete();

        Assert.NotNull(requested);
        Assert.Single(requested!.Entries);
        Assert.Equal("/left/a.txt", requested.Entries[0].FullPath);
    }

    [Fact]
    public void RequestDelete_NoMarkedEntriesAndNoCursorEntry_DoesNotRaiseDeleteRequested()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left");
        fs.AddDirectory("/right");
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history);
        var raised = false;
        vm.DeleteRequested += (_, _) => raised = true;

        vm.RequestDelete();

        Assert.False(raised);
    }

    [Fact]
    public void RequestMkdir_RaisesMkdirRequestedForActivePanelDirectory()
    {
        var (fs, trash, history) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history);
        MkdirDialogViewModel? requested = null;
        vm.MkdirRequested += (_, dialog) => requested = dialog;

        vm.RequestMkdir();

        Assert.NotNull(requested);
        Assert.Equal("/left", requested!.ParentDirectory);
    }
}
