using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Tests.ViewModels;

public class ConflictDialogViewModelTests
{
    [Fact]
    public async Task Overwrite_CompletesResultWithOverwriteResolution()
    {
        var vm = new ConflictDialogViewModel("/dest/file.txt");

        vm.OverwriteCommand.Execute(null);

        var result = await vm.ResultTask;
        Assert.Equal(FileConflictResolution.Overwrite, result.Resolution);
        Assert.False(result.ApplyToAll);
    }

    [Fact]
    public async Task Skip_CompletesResultWithSkipResolution()
    {
        var vm = new ConflictDialogViewModel("/dest/file.txt");

        vm.SkipCommand.Execute(null);

        var result = await vm.ResultTask;
        Assert.Equal(FileConflictResolution.Skip, result.Resolution);
    }

    [Fact]
    public async Task Rename_CompletesResultWithRenameResolution()
    {
        var vm = new ConflictDialogViewModel("/dest/file.txt");

        vm.RenameCommand.Execute(null);

        var result = await vm.ResultTask;
        Assert.Equal(FileConflictResolution.Rename, result.Resolution);
    }

    [Fact]
    public async Task Abort_CompletesResultWithAbortResolution()
    {
        var vm = new ConflictDialogViewModel("/dest/file.txt");

        vm.AbortCommand.Execute(null);

        var result = await vm.ResultTask;
        Assert.Equal(FileConflictResolution.Abort, result.Resolution);
    }

    [Fact]
    public async Task Update_CompletesResultWithUpdateResolution()
    {
        var vm = new ConflictDialogViewModel("/dest/file.txt");

        vm.UpdateCommand.Execute(null);

        var result = await vm.ResultTask;
        Assert.Equal(FileConflictResolution.Update, result.Resolution);
    }

    [Fact]
    public async Task ApplyToAll_WhenChecked_IsCarriedIntoResult()
    {
        var vm = new ConflictDialogViewModel("/dest/file.txt") { ApplyToAll = true };

        vm.OverwriteCommand.Execute(null);

        var result = await vm.ResultTask;
        Assert.True(result.ApplyToAll);
    }

    [Fact]
    public async Task Update_WithApplyToAll_CarriesApplyToAllIntoResult()
    {
        var vm = new ConflictDialogViewModel("/dest/file.txt") { ApplyToAll = true };

        vm.UpdateCommand.Execute(null);

        var result = await vm.ResultTask;
        Assert.Equal(FileConflictResolution.Update, result.Resolution);
        Assert.True(result.ApplyToAll);
    }

    [Fact]
    public void DestinationPath_ExposesConstructorValue()
    {
        var vm = new ConflictDialogViewModel("/dest/dup.txt");

        Assert.Equal("/dest/dup.txt", vm.DestinationPath);
    }
}
