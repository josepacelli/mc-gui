using McGui.App.Tests.Fakes;
using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Tests.ViewModels;

public class MainWindowViewModelTests
{
    private static FileEntry File(string name, string parent) =>
        new(name, Path.Combine(parent, name), IsDirectory: false, SizeBytes: 10, DateTimeOffset.UnixEpoch, IsSymlink: false, IsHidden: false);

    private static MainWindowViewModel CreateViewModel()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left", File("a.txt", "/left"));
        fs.AddDirectory("/right", File("b.txt", "/right"));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        return new MainWindowViewModel(fs, history);
    }

    [Fact]
    public void Constructor_StartsWithLeftPanelActive()
    {
        var vm = CreateViewModel();

        Assert.Same(vm.LeftPanel, vm.ActivePanel);
        Assert.True(vm.LeftPanel.IsActive);
        Assert.False(vm.RightPanel.IsActive);
    }

    [Fact]
    public void SwitchActivePanel_FromLeft_MovesFocusAndHighlightToRightPanel()
    {
        var vm = CreateViewModel();

        vm.SwitchActivePanel();

        Assert.Same(vm.RightPanel, vm.ActivePanel);
        Assert.True(vm.RightPanel.IsActive);
        Assert.False(vm.LeftPanel.IsActive);
    }

    [Fact]
    public void SwitchActivePanel_CalledTwice_ReturnsFocusToLeftPanel()
    {
        var vm = CreateViewModel();

        vm.SwitchActivePanel();
        vm.SwitchActivePanel();

        Assert.Same(vm.LeftPanel, vm.ActivePanel);
        Assert.True(vm.LeftPanel.IsActive);
        Assert.False(vm.RightPanel.IsActive);
    }
}
