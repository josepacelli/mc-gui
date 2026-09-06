using McGui.App.Tests.Fakes;
using McGui.App.ViewModels;
using McGui.Core.Models;
using McGui.Infrastructure.macOS;

namespace McGui.App.Tests.ViewModels;

public class ViewerViewModelTests : IDisposable
{
    private readonly DirectoryInfo _root = Directory.CreateTempSubdirectory("mcgui-viewer-vm-");
    private readonly MacViewerService _viewerService = new();
    private readonly FakeFileSystemService _fileSystemService = new();

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

    private static string WriteFile(string dir, string name, string content = "content")
    {
        var path = Path.Combine(dir, name);
        File.WriteAllText(path, content);
        return path;
    }

    private ViewerViewModel CreateViewModel() => new(_viewerService);

    [Fact]
    public async Task LoadCommand_TextFile_LoadsContentAndSetsProperties()
    {
        var source = NewSubdir("load-text");
        var filePath = WriteFile(source, "test.txt", "Line 1\nLine 2\nLine 3");
        var vm = CreateViewModel();

        vm.FilePath = filePath;
        await vm.LoadCommand.ExecuteAsync(null);

        Assert.Equal("test.txt", vm.Title);
        Assert.Equal("Line 1\nLine 2\nLine 3", vm.Content);
        Assert.Equal(3, vm.Lines.Length);
        Assert.Equal("UTF-8", vm.Encoding);
        Assert.False(vm.IsBinary);
        Assert.Equal(ViewerMode.Text, vm.Mode);
    }

    [Fact]
    public async Task LoadCommand_BinaryFile_SwitchesToHexMode()
    {
        var source = NewSubdir("load-binary");
        var filePath = Path.Combine(source, "test.bin");
        await File.WriteAllBytesAsync(filePath, new byte[] { 0x00, 0x01, 0x02, 0x03 });
        var vm = CreateViewModel();

        vm.FilePath = filePath;
        await vm.LoadCommand.ExecuteAsync(null);

        Assert.Equal(ViewerMode.Hex, vm.Mode);
        Assert.True(vm.IsBinary);
        Assert.NotEmpty(vm.Lines);
    }

    [Fact]
    public async Task LoadCommand_EmptyFile_SetsEmptyContent()
    {
        var source = NewSubdir("load-empty");
        var filePath = WriteFile(source, "empty.txt", string.Empty);
        var vm = CreateViewModel();

        vm.FilePath = filePath;
        await vm.LoadCommand.ExecuteAsync(null);

        Assert.Equal(string.Empty, vm.Content);
        Assert.Equal(0, vm.FileSize);
    }

    [Fact]
    public void ToggleWrap_FlipsWordWrap()
    {
        var vm = CreateViewModel();
        var initial = vm.WordWrap;

        vm.ToggleWrapCommand.Execute(null);

        Assert.Equal(!initial, vm.WordWrap);
    }

    [Fact]
    public void ToggleHex_TextMode_SwitchesToHex()
    {
        var vm = CreateViewModel();
        vm.Content = "Hello World";
        vm.Lines = ["Hello World"];
        vm.IsBinary = false;

        vm.ToggleHexCommand.Execute(null);

        Assert.Equal(ViewerMode.Hex, vm.Mode);
        Assert.NotEmpty(vm.Lines);
    }

    [Fact]
    public void ToggleHex_HexMode_DoesNotSwitchBackWithoutReload()
    {
        var vm = CreateViewModel();
        vm.Mode = ViewerMode.Hex;
        vm.IsBinary = false;

        vm.ToggleHexCommand.Execute(null);

        Assert.Equal(ViewerMode.Hex, vm.Mode);
    }

    [Fact]
    public void ScrollUp_DecreasesOffset()
    {
        var vm = CreateViewModel();
        vm.Lines = ["1", "2", "3", "4", "5"];
        vm.ScrollOffset = 2;

        vm.ScrollUp();

        Assert.Equal(1, vm.ScrollOffset);
    }

    [Fact]
    public void ScrollUp_AtTop_StaysAtZero()
    {
        var vm = CreateViewModel();
        vm.Lines = ["1", "2", "3"];
        vm.ScrollOffset = 0;

        vm.ScrollUp();

        Assert.Equal(0, vm.ScrollOffset);
    }

    [Fact]
    public void ScrollDown_IncreasesOffset()
    {
        var vm = CreateViewModel();
        vm.Lines = ["1", "2", "3", "4", "5"];
        vm.ScrollOffset = 1;

        vm.ScrollDown();

        Assert.Equal(2, vm.ScrollOffset);
    }

    [Fact]
    public void ScrollDown_AtBottom_StaysAtLastLine()
    {
        var vm = CreateViewModel();
        vm.Lines = ["1", "2", "3"];
        vm.ScrollOffset = 2;

        vm.ScrollDown();

        Assert.Equal(2, vm.ScrollOffset);
    }

    [Fact]
    public void ScrollPageUp_MovesBy20Lines()
    {
        var vm = CreateViewModel();
        vm.Lines = Enumerable.Range(1, 50).Select(i => i.ToString()).ToArray();
        vm.ScrollOffset = 30;

        vm.ScrollPageUp();

        Assert.Equal(10, vm.ScrollOffset);
    }

    [Fact]
    public void ScrollPageDown_MovesBy20Lines()
    {
        var vm = CreateViewModel();
        vm.Lines = Enumerable.Range(1, 50).Select(i => i.ToString()).ToArray();
        vm.ScrollOffset = 10;

        vm.ScrollPageDown();

        Assert.Equal(30, vm.ScrollOffset);
    }

    [Fact]
    public void ScrollToTop_SetsOffsetToZero()
    {
        var vm = CreateViewModel();
        vm.ScrollOffset = 100;

        vm.ScrollToTop();

        Assert.Equal(0, vm.ScrollOffset);
    }

    [Fact]
    public void ScrollToBottom_SetsOffsetToLastLine()
    {
        var vm = CreateViewModel();
        vm.Lines = ["1", "2", "3"];

        vm.ScrollToBottom();

        Assert.Equal(2, vm.ScrollOffset);
    }

    [Fact]
    public void CloseCommand_RaisesCloseRequested()
    {
        var vm = CreateViewModel();
        var raised = false;
        vm.CloseRequested += () => raised = true;

        vm.CloseCommand.Execute(null);

        Assert.True(raised);
    }
}