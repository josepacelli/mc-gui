using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Tests.ViewModels;

public class ProgressDialogViewModelTests
{
    [Fact]
    public void Report_UpdatesCurrentFileNameAndFilesDone()
    {
        var vm = new ProgressDialogViewModel(() => { });

        vm.Report(new OperationProgress("a.txt", 1, 4, 10, 40, IsCancelled: false));

        Assert.Equal("a.txt", vm.CurrentFileName);
        Assert.Equal(1, vm.FilesDone);
        Assert.Equal(4, vm.FilesTotal);
    }

    [Fact]
    public void PercentComplete_WithBytesTotal_ComputesFromBytes()
    {
        var vm = new ProgressDialogViewModel(() => { });

        vm.Report(new OperationProgress("a.txt", 1, 4, 25, 100, IsCancelled: false));

        Assert.Equal(25, vm.PercentComplete);
    }

    [Fact]
    public void PercentComplete_WithoutBytesTotal_FallsBackToFileCount()
    {
        var vm = new ProgressDialogViewModel(() => { });

        vm.Report(new OperationProgress("dir", 1, 2, 0, 0, IsCancelled: false));

        Assert.Equal(50, vm.PercentComplete);
    }

    [Fact]
    public void Cancel_SetsIsCancelledAndInvokesRequestCancel()
    {
        var cancelled = false;
        var vm = new ProgressDialogViewModel(() => cancelled = true);

        vm.CancelCommand.Execute(null);

        Assert.True(vm.IsCancelled);
        Assert.True(cancelled);
    }
}
