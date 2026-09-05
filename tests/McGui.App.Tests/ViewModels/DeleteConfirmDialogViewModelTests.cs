using System.Runtime.Versioning;
using McGui.App.ViewModels;
using McGui.Core.Interfaces;
using McGui.Core.Models;
using McGui.Infrastructure.macOS;

namespace McGui.App.Tests.ViewModels;

[SupportedOSPlatform("macos")]
public class DeleteConfirmDialogViewModelTests : IDisposable
{
    private readonly DirectoryInfo _root = Directory.CreateTempSubdirectory("mcgui-delete-vm-");

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

    private sealed class BlockingTrashService(ManualResetEventSlim gate) : ITrashService
    {
        public OperationResult Delete(IReadOnlyList<FileEntry> entries, bool permanent)
        {
            gate.Wait();
            return new OperationResult(true, []);
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

    private static FileEntry ToEntry(string fullPath) =>
        new(Path.GetFileName(fullPath), fullPath, IsDirectory: false, new FileInfo(fullPath).Length,
            DateTimeOffset.UtcNow, IsSymlink: false, IsHidden: false);

    [Fact]
    public void Count_And_TotalSizeBytes_ReflectMarkedEntries()
    {
        var source = NewSubdir("count-src");
        var file1 = WriteFile(source, "a.txt", "12345");
        var file2 = WriteFile(source, "b.txt", "1234567890");
        var trashService = new MacTrashService(trashRootForPath: _ => NewSubdir("trash"));
        var vm = new DeleteConfirmDialogViewModel(trashService, [ToEntry(file1), ToEntry(file2)]);

        Assert.Equal(2, vm.Count);
        Assert.Equal(15, vm.TotalSizeBytes);
    }

    [Fact]
    public async Task Confirm_MovesEntryToTrashAndExposesResult()
    {
        var source = NewSubdir("trash-src");
        var filePath = WriteFile(source, "doomed.txt");
        var trashDir = NewSubdir("trash-dst");
        var trashService = new MacTrashService(trashRootForPath: _ => trashDir);
        var vm = new DeleteConfirmDialogViewModel(trashService, [ToEntry(filePath)]);

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.True(vm.IsCompleted);
        Assert.False(vm.Permanent);
        Assert.NotNull(vm.Result);
        Assert.True(vm.Result!.Succeeded);
        Assert.False(File.Exists(filePath));
        Assert.True(File.Exists(Path.Combine(trashDir, "doomed.txt")));
    }

    [Fact]
    public async Task ConfirmPermanent_DeletesEntryWithoutUsingTrash()
    {
        var source = NewSubdir("permanent-src");
        var filePath = WriteFile(source, "gone.txt");
        var trashDir = NewSubdir("permanent-trash");
        var trashService = new MacTrashService(trashRootForPath: _ => trashDir);
        var vm = new DeleteConfirmDialogViewModel(trashService, [ToEntry(filePath)]);

        await vm.ConfirmPermanentCommand.ExecuteAsync(null);

        Assert.True(vm.IsCompleted);
        Assert.True(vm.Permanent);
        Assert.False(File.Exists(filePath));
        Assert.Empty(Directory.EnumerateFileSystemEntries(trashDir));
    }

    [Fact]
    public async Task Confirm_DoesNotCompleteUntilBackgroundDeleteReturns()
    {
        var source = NewSubdir("async-src");
        var filePath = WriteFile(source, "doomed.txt");
        using var gate = new ManualResetEventSlim();
        var vm = new DeleteConfirmDialogViewModel(new BlockingTrashService(gate), [ToEntry(filePath)]);

        var deleteTask = vm.ConfirmCommand.ExecuteAsync(null);

        Assert.False(vm.IsCompleted);

        gate.Set();
        await deleteTask;

        Assert.True(vm.IsCompleted);
        Assert.True(vm.Result!.Succeeded);
    }
}
