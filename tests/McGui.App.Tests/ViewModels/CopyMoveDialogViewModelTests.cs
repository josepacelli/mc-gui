using System.Runtime.Versioning;
using McGui.App.Tests.Fakes;
using McGui.App.ViewModels;
using McGui.Core.Models;
using McGui.Core.Services;
using McGui.Infrastructure.macOS;

namespace McGui.App.Tests.ViewModels;

[SupportedOSPlatform("macos")]
public class CopyMoveDialogViewModelTests : IDisposable
{
    private readonly DirectoryInfo _root = Directory.CreateTempSubdirectory("mcgui-copymove-vm-");
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

    private static FileEntry ToEntry(string fullPath, bool isDirectory) =>
        new(Path.GetFileName(fullPath), fullPath, isDirectory, isDirectory ? 0 : new FileInfo(fullPath).Length,
            DateTimeOffset.UtcNow, IsSymlink: false, IsHidden: Path.GetFileName(fullPath).StartsWith('.'));

    private CopyMoveDialogViewModel BuildViewModel(
        IReadOnlyList<FileEntry> sources,
        string destination,
        OperationMode mode,
        IConflictPrompt? conflictPrompt = null,
        string? otherPanelCurrentDir = null) =>
        new(_fileSystemService, new CopyMovePlanner(_fileSystemService), conflictPrompt ?? new FakeConflictPrompt(), sources, destination, mode, otherPanelCurrentDir);

    [Fact]
    public async Task ConfirmAsync_Copy_CopiesFileAndReportsProgress()
    {
        var source = NewSubdir("copy-src");
        var filePath = WriteFile(source, "a.txt", "hello");
        var destination = NewSubdir("copy-dst");
        var vm = BuildViewModel([ToEntry(filePath, false)], destination, OperationMode.Copy);
        var reportedCount = 0;
        vm.ProgressReported += (_, _) => reportedCount++;

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.True(vm.IsCompleted);
        Assert.Null(vm.ErrorMessage);
        Assert.True(File.Exists(Path.Combine(destination, "a.txt")));
        Assert.Equal(1, reportedCount);
        Assert.NotNull(vm.LastProgress);
        Assert.Equal(1, vm.LastProgress!.FilesDone);
    }

    [Fact]
    public async Task ConfirmAsync_Move_MovesFileToDestination()
    {
        var source = NewSubdir("move-src");
        var filePath = WriteFile(source, "move-me.txt");
        var destination = NewSubdir("move-dst");
        var vm = BuildViewModel([ToEntry(filePath, false)], destination, OperationMode.Move);

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.True(vm.IsCompleted);
        Assert.False(File.Exists(filePath));
        Assert.True(File.Exists(Path.Combine(destination, "move-me.txt")));
    }

    [Fact]
    public async Task ConfirmAsync_MoveSingleSourceWithChangedName_RenamesInPlace()
    {
        var source = NewSubdir("rename-src");
        var filePath = WriteFile(source, "old-name.txt", "payload");
        var vm = BuildViewModel([ToEntry(filePath, false)], source, OperationMode.Move);
        vm.NewName = "new-name.txt";

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.True(vm.IsCompleted);
        Assert.False(File.Exists(filePath));
        Assert.True(File.Exists(Path.Combine(source, "new-name.txt")));
        Assert.Equal("payload", File.ReadAllText(Path.Combine(source, "new-name.txt")));
    }

    [Fact]
    public void CanRename_MultipleSourcesOrCopyMode_IsFalse()
    {
        var source = NewSubdir("multi-src");
        var file1 = WriteFile(source, "a.txt");
        var file2 = WriteFile(source, "b.txt");
        var multiVm = BuildViewModel([ToEntry(file1, false), ToEntry(file2, false)], source, OperationMode.Move);
        var copyVm = BuildViewModel([ToEntry(file1, false)], source, OperationMode.Copy);

        Assert.False(multiVm.CanRename);
        Assert.False(copyVm.CanRename);
    }

    [Theory]
    [InlineData(FileConflictResolution.Overwrite, "new-content")]
    [InlineData(FileConflictResolution.Skip, "old-content")]
    public async Task ConfirmAsync_NameConflict_PromptsAndAppliesResolution(FileConflictResolution resolution, string expectedContent)
    {
        var source = NewSubdir($"conflict-src-{resolution}");
        var filePath = WriteFile(source, "dup.txt", "new-content");
        var destination = NewSubdir($"conflict-dst-{resolution}");
        WriteFile(destination, "dup.txt", "old-content");
        var prompt = new FakeConflictPrompt(new ConflictPromptResult(resolution, ApplyToAll: false));
        var vm = BuildViewModel([ToEntry(filePath, false)], destination, OperationMode.Copy, prompt);

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.Single(prompt.PromptedPaths);
        Assert.Equal(expectedContent, File.ReadAllText(Path.Combine(destination, "dup.txt")));
    }

    [Fact]
    public async Task ConfirmAsync_ConflictWithApplyToAll_PromptsOnlyOnce()
    {
        var source = NewSubdir("apply-all-src");
        var file1 = WriteFile(source, "a.txt", "1");
        var file2 = WriteFile(source, "b.txt", "2");
        var destination = NewSubdir("apply-all-dst");
        WriteFile(destination, "a.txt", "old-a");
        WriteFile(destination, "b.txt", "old-b");
        var prompt = new FakeConflictPrompt(new ConflictPromptResult(FileConflictResolution.Overwrite, ApplyToAll: true));
        var vm = BuildViewModel([ToEntry(file1, false), ToEntry(file2, false)], destination, OperationMode.Copy, prompt);

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.Single(prompt.PromptedPaths);
        Assert.Equal("1", File.ReadAllText(Path.Combine(destination, "a.txt")));
        Assert.Equal("2", File.ReadAllText(Path.Combine(destination, "b.txt")));
    }

    [Fact]
    public async Task Cancel_DuringCopy_StopsAfterCurrentFileWithoutRollback()
    {
        var source = NewSubdir("cancel-src");
        var file1 = WriteFile(source, "a.txt");
        var file2 = WriteFile(source, "b.txt");
        var destination = NewSubdir("cancel-dst");
        var vm = BuildViewModel([ToEntry(file1, false), ToEntry(file2, false)], destination, OperationMode.Copy);
        vm.ProgressReported += (_, progress) =>
        {
            if (progress.FilesDone == 1)
            {
                vm.CancelCommand.Execute(null);
            }
        };

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.True(File.Exists(Path.Combine(destination, "a.txt")));
        Assert.False(File.Exists(Path.Combine(destination, "b.txt")));
    }

    [Fact]
    public async Task ConfirmAsync_DestinationDoesNotExist_CreatesItAsPartOfConfirming()
    {
        var source = NewSubdir("missing-dest-src");
        var filePath = WriteFile(source, "a.txt", "hello");
        var destination = Path.Combine(_root.FullName, "missing-dest-dst");
        var vm = BuildViewModel([ToEntry(filePath, false)], destination, OperationMode.Copy);

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.True(vm.IsCompleted);
        Assert.Null(vm.ErrorMessage);
        Assert.True(Directory.Exists(destination));
        Assert.True(File.Exists(Path.Combine(destination, "a.txt")));
    }

    [Fact]
    public async Task ConfirmAsync_CircularCopyWithMissingDestination_DoesNotCreateDestinationDirectory()
    {
        var source = NewSubdir("circular-missing-src");
        WriteFile(source, "keep.txt");
        var missingSubdir = Path.Combine(source, "sub");
        var vm = BuildViewModel([ToEntry(source, true)], missingSubdir, OperationMode.Copy);

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.False(vm.IsCompleted);
        Assert.NotNull(vm.ErrorMessage);
        Assert.False(Directory.Exists(missingSubdir));
    }

    [Fact]
    public async Task ConfirmAsync_CircularCopy_SetsErrorMessageAndDoesNotCopy()
    {
        var source = NewSubdir("circular-src");
        WriteFile(source, "keep.txt");
        var vm = BuildViewModel([ToEntry(source, true)], Path.Combine(source, "sub"), OperationMode.Copy);

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.False(vm.IsCompleted);
        Assert.NotNull(vm.ErrorMessage);
        Assert.Contains("circular", vm.ErrorMessage, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ConfirmAsync_MoveBlockedByOtherPanelCurrentDirectory_SetsErrorMessage()
    {
        var source = NewSubdir("blocked-src");
        var destination = NewSubdir("blocked-dst");
        var vm = BuildViewModel([ToEntry(source, true)], destination, OperationMode.Move, otherPanelCurrentDir: source);

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.False(vm.IsCompleted);
        Assert.NotNull(vm.ErrorMessage);
        Assert.Contains("other panel", vm.ErrorMessage, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ConfirmAsync_InsufficientDiskSpace_SetsErrorMessageWithByteCounts()
    {
        var source = NewSubdir("space-src");
        var filePath = WriteFile(source, "big.txt", "content");
        var destination = NewSubdir("space-dst");
        var lowSpaceFileSystem = new MacFileSystemService(_ => 1);
        var vm = new CopyMoveDialogViewModel(
            lowSpaceFileSystem,
            new CopyMovePlanner(lowSpaceFileSystem),
            new FakeConflictPrompt(),
            [ToEntry(filePath, false)],
            destination,
            OperationMode.Copy,
            otherPanelCurrentDir: null);

        await vm.ConfirmCommand.ExecuteAsync(null);

        Assert.False(vm.IsCompleted);
        Assert.Equal("Insufficient disk space: required 7 bytes, available 1 bytes.", vm.ErrorMessage);
        Assert.False(File.Exists(Path.Combine(destination, "big.txt")));
    }
}
