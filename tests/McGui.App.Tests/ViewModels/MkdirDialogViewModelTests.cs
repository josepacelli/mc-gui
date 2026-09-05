using System.Runtime.Versioning;
using McGui.App.ViewModels;
using McGui.Infrastructure.macOS;

namespace McGui.App.Tests.ViewModels;

[SupportedOSPlatform("macos")]
public class MkdirDialogViewModelTests : IDisposable
{
    private readonly DirectoryInfo _root = Directory.CreateTempSubdirectory("mcgui-mkdir-vm-");
    private readonly MacFileSystemService _fileSystemService = new();

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

    [Fact]
    public void Confirm_ValidName_CreatesDirectoryAndCompletes()
    {
        var vm = new MkdirDialogViewModel(_fileSystemService, _root.FullName) { Name = "new-folder" };

        vm.ConfirmCommand.Execute(null);

        Assert.True(vm.IsCompleted);
        Assert.Null(vm.ErrorMessage);
        Assert.True(Directory.Exists(Path.Combine(_root.FullName, "new-folder")));
    }

    [Fact]
    public void Confirm_DuplicateName_SetsInlineErrorAndStaysOpen()
    {
        Directory.CreateDirectory(Path.Combine(_root.FullName, "existing"));
        var vm = new MkdirDialogViewModel(_fileSystemService, _root.FullName) { Name = "existing" };

        vm.ConfirmCommand.Execute(null);

        Assert.False(vm.IsCompleted);
        Assert.NotNull(vm.ErrorMessage);
        Assert.True(vm.HasError);
    }

    [Fact]
    public void Confirm_InvalidCharacter_SetsInlineErrorIdentifyingCharacter()
    {
        var vm = new MkdirDialogViewModel(_fileSystemService, _root.FullName) { Name = "bad/name" };

        vm.ConfirmCommand.Execute(null);

        Assert.False(vm.IsCompleted);
        Assert.NotNull(vm.ErrorMessage);
        Assert.Contains('/', vm.ErrorMessage);
    }

    [Fact]
    public void HasError_WhenNoErrorMessage_IsFalse()
    {
        var vm = new MkdirDialogViewModel(_fileSystemService, _root.FullName);

        Assert.False(vm.HasError);
    }
}
