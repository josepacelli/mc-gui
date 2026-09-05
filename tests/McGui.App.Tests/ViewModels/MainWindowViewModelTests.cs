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
}
