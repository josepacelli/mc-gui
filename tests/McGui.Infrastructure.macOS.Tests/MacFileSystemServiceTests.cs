using System.Runtime.Versioning;
using McGui.Core.Models;
using McGui.Infrastructure.macOS;
using static McGui.Infrastructure.macOS.Tests.TempDirectoryFixture;

namespace McGui.Infrastructure.macOS.Tests;

[SupportedOSPlatform("macos")]
public class MacFileSystemServiceTests : IDisposable
{
    private readonly TempDirectoryFixture _temp = new("mcgui-fs-");
    private readonly MacFileSystemService _sut = new();

    public void Dispose() => _temp.Dispose();

    private static Func<string, FileConflictResolution> AlwaysReturn(FileConflictResolution resolution) => _ => resolution;

    private sealed class SynchronousProgress(Action<OperationProgress> callback) : IProgress<OperationProgress>
    {
        public void Report(OperationProgress value) => callback(value);
    }

    [Fact]
    public void ListDirectory_ReturnsFilesAndDirectoriesWithExpectedMetadata()
    {
        var source = _temp.NewSubdir("list-src");
        WriteFile(source, "visible.txt", "hello");
        WriteFile(source, ".hidden.txt", "secret");
        Directory.CreateDirectory(Path.Combine(source, "subdir"));

        var entries = _sut.ListDirectory(source);

        var visible = Assert.Single(entries, e => e.Name == "visible.txt");
        Assert.False(visible.IsDirectory);
        Assert.Equal(5, visible.SizeBytes);
        Assert.False(visible.IsHidden);

        var hidden = Assert.Single(entries, e => e.Name == ".hidden.txt");
        Assert.True(hidden.IsHidden);

        var subdir = Assert.Single(entries, e => e.Name == "subdir");
        Assert.True(subdir.IsDirectory);
    }

    [Fact]
    public void ListDirectory_SymbolicLink_IsFlaggedAsSymlink()
    {
        var source = _temp.NewSubdir("list-symlink-src");
        var targetFile = WriteFile(source, "target.txt", "target-content");
        var linkPath = Path.Combine(source, "link-to-target.txt");
        File.CreateSymbolicLink(linkPath, targetFile);

        var entries = _sut.ListDirectory(source);

        var link = Assert.Single(entries, e => e.Name == "link-to-target.txt");
        Assert.True(link.IsSymlink);

        var target = Assert.Single(entries, e => e.Name == "target.txt");
        Assert.False(target.IsSymlink);
    }

    [Fact]
    public void CreateDirectory_CreatesFolderInsideParent()
    {
        var parent = _temp.NewSubdir("mkdir-parent");

        _sut.CreateDirectory(parent, "new-folder");

        Assert.True(Directory.Exists(Path.Combine(parent, "new-folder")));
    }

    [Fact]
    public void CreateDirectory_DuplicateName_ThrowsIOException()
    {
        var parent = _temp.NewSubdir("mkdir-dup");
        Directory.CreateDirectory(Path.Combine(parent, "existing"));

        Assert.Throws<IOException>(() => _sut.CreateDirectory(parent, "existing"));
    }

    [Fact]
    public void CreateDirectory_InvalidCharacter_ThrowsArgumentExceptionIdentifyingChar()
    {
        var parent = _temp.NewSubdir("mkdir-invalid");

        var ex = Assert.Throws<ArgumentException>(() => _sut.CreateDirectory(parent, "bad/name"));

        Assert.Contains('/', ex.Message);
    }

    [Fact]
    public async Task CopyAsync_DirectoryWithSubfile_CopiesRecursively()
    {
        var source = _temp.NewSubdir("copy-src");
        var subDir = Directory.CreateDirectory(Path.Combine(source, "sub")).FullName;
        var filePath = WriteFile(subDir, "nested.txt", "nested-content");
        var destination = _temp.NewSubdir("copy-dst");

        var sourceDirEntry = ToEntry(source, isDirectory: true);
        var sourceSubEntry = ToEntry(subDir, isDirectory: true);
        var sourceFileEntry = ToEntry(filePath, isDirectory: false);
        var plan = new CopyMovePlan([sourceDirEntry, sourceSubEntry, sourceFileEntry], destination, OperationMode.Copy);

        var result = await _sut.CopyAsync(plan, new Progress<OperationProgress>(), AlwaysReturn(FileConflictResolution.Abort), CancellationToken.None);

        Assert.True(result.Succeeded);
        Assert.Empty(result.SkippedEntries);
        var copiedFile = Path.Combine(destination, "copy-src", "sub", "nested.txt");
        Assert.True(File.Exists(copiedFile));
        Assert.Equal("nested-content", File.ReadAllText(copiedFile));
    }

    [Fact]
    public async Task CopyAsync_ReportsProgressForEachEntry()
    {
        var source = _temp.NewSubdir("copy-progress-src");
        var file1 = WriteFile(source, "a.txt");
        var file2 = WriteFile(source, "b.txt");
        var destination = _temp.NewSubdir("copy-progress-dst");

        var plan = new CopyMovePlan([ToEntry(file1, false), ToEntry(file2, false)], destination, OperationMode.Copy);
        var reports = new List<OperationProgress>();
        var progress = new SynchronousProgress(reports.Add);

        await _sut.CopyAsync(plan, progress, AlwaysReturn(FileConflictResolution.Abort), CancellationToken.None);

        Assert.Equal(2, reports.Count);
        Assert.Equal(2, reports[^1].FilesDone);
        Assert.Equal(2, reports[^1].FilesTotal);
    }

    [Fact]
    public async Task CopyAsync_CancelledBeforeSecondFile_StopsWithoutRollingBackFirstFile()
    {
        var source = _temp.NewSubdir("copy-cancel-src");
        var file1 = WriteFile(source, "a.txt");
        var file2 = WriteFile(source, "b.txt");
        var destination = _temp.NewSubdir("copy-cancel-dst");

        var plan = new CopyMovePlan([ToEntry(file1, false), ToEntry(file2, false)], destination, OperationMode.Copy);
        using var cts = new CancellationTokenSource();
        var reports = new List<OperationProgress>();
        var progress = new SynchronousProgress(p =>
        {
            reports.Add(p);
            if (p.FilesDone == 1)
            {
                cts.Cancel();
            }
        });

        var result = await _sut.CopyAsync(plan, progress, AlwaysReturn(FileConflictResolution.Abort), cts.Token);

        Assert.True(File.Exists(Path.Combine(destination, "a.txt")));
        Assert.False(File.Exists(Path.Combine(destination, "b.txt")));
        Assert.True(result.Succeeded);
    }

    [Theory]
    [InlineData(FileConflictResolution.Overwrite)]
    [InlineData(FileConflictResolution.Skip)]
    [InlineData(FileConflictResolution.Rename)]
    public async Task CopyAsync_NameConflict_AppliesRequestedResolution(FileConflictResolution resolution)
    {
        var source = _temp.NewSubdir($"conflict-src-{resolution}");
        var filePath = WriteFile(source, "dup.txt", "new-content");
        var destination = _temp.NewSubdir($"conflict-dst-{resolution}");
        WriteFile(destination, "dup.txt", "old-content");

        var plan = new CopyMovePlan([ToEntry(filePath, false)], destination, OperationMode.Copy);

        var result = await _sut.CopyAsync(plan, new Progress<OperationProgress>(), AlwaysReturn(resolution), CancellationToken.None);

        Assert.True(result.Succeeded);
        var destFile = Path.Combine(destination, "dup.txt");
        switch (resolution)
        {
            case FileConflictResolution.Overwrite:
                Assert.Equal("new-content", File.ReadAllText(destFile));
                break;
            case FileConflictResolution.Skip:
                Assert.Equal("old-content", File.ReadAllText(destFile));
                break;
            case FileConflictResolution.Rename:
                Assert.Equal("old-content", File.ReadAllText(destFile));
                Assert.Equal("new-content", File.ReadAllText(Path.Combine(destination, "dup 2.txt")));
                break;
        }
    }

    [Fact]
    public async Task CopyAsync_NameConflictWithAbort_StopsOperationAndReportsFailure()
    {
        var source = _temp.NewSubdir("abort-src");
        var filePath = WriteFile(source, "dup.txt", "new-content");
        var destination = _temp.NewSubdir("abort-dst");
        WriteFile(destination, "dup.txt", "old-content");

        var plan = new CopyMovePlan([ToEntry(filePath, false)], destination, OperationMode.Copy);

        var result = await _sut.CopyAsync(plan, new Progress<OperationProgress>(), AlwaysReturn(FileConflictResolution.Abort), CancellationToken.None);

        Assert.False(result.Succeeded);
        Assert.Single(result.SkippedEntries);
        Assert.Equal("old-content", File.ReadAllText(Path.Combine(destination, "dup.txt")));
    }

    [Fact]
    public async Task CopyAsync_InsufficientSpace_ThrowsBeforeCopyingAnyFile()
    {
        var source = _temp.NewSubdir("space-src");
        var filePath = WriteFile(source, "big.txt", "content");
        var destination = _temp.NewSubdir("space-dst");
        var lowSpaceService = new MacFileSystemService(_ => 1);
        var plan = new CopyMovePlan([ToEntry(filePath, false)], destination, OperationMode.Copy);

        var ex = await Assert.ThrowsAsync<InsufficientDiskSpaceException>(
            () => lowSpaceService.CopyAsync(plan, new Progress<OperationProgress>(), AlwaysReturn(FileConflictResolution.Abort), CancellationToken.None));

        Assert.Equal(1, ex.AvailableBytes);
        Assert.False(File.Exists(Path.Combine(destination, "big.txt")));
    }

    [Fact]
    public async Task CopyAsync_PermissionDenied_SkipsEntryAndContinuesReportingReason()
    {
        var source = _temp.NewSubdir("perm-copy-src");
        var file1 = WriteFile(source, "one.txt");
        var file2 = WriteFile(source, "two.txt");
        var destination = _temp.NewSubdir("perm-copy-dst");
        File.SetUnixFileMode(destination, UnixFileMode.UserRead | UnixFileMode.UserExecute);

        try
        {
            var plan = new CopyMovePlan([ToEntry(file1, false), ToEntry(file2, false)], destination, OperationMode.Copy);

            var result = await _sut.CopyAsync(plan, new Progress<OperationProgress>(), AlwaysReturn(FileConflictResolution.Abort), CancellationToken.None);

            Assert.True(result.Succeeded);
            Assert.Equal(2, result.SkippedEntries.Count);
            Assert.Contains(result.SkippedEntries, s => s.Path == file1);
            Assert.Contains(result.SkippedEntries, s => s.Path == file2);
        }
        finally
        {
            File.SetUnixFileMode(destination, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        }
    }

    [Fact]
    public async Task MoveAsync_NameConflictWithOverwrite_ReplacesDestinationEntry()
    {
        var source = _temp.NewSubdir("move-conflict-src");
        var filePath = WriteFile(source, "dup.txt", "new-content");
        var destination = _temp.NewSubdir("move-conflict-dst");
        WriteFile(destination, "dup.txt", "old-content");

        var plan = new CopyMovePlan([ToEntry(filePath, false)], destination, OperationMode.Move);

        var result = await _sut.MoveAsync(plan, new Progress<OperationProgress>(), AlwaysReturn(FileConflictResolution.Overwrite), CancellationToken.None);

        Assert.True(result.Succeeded);
        Assert.False(File.Exists(filePath));
        Assert.Equal("new-content", File.ReadAllText(Path.Combine(destination, "dup.txt")));
    }

    [Fact]
    public async Task MoveAsync_MovesEntryToDestinationDirectory()
    {
        var source = _temp.NewSubdir("move-src");
        var filePath = WriteFile(source, "move-me.txt", "payload");
        var destination = _temp.NewSubdir("move-dst");

        var plan = new CopyMovePlan([ToEntry(filePath, false)], destination, OperationMode.Move);

        var result = await _sut.MoveAsync(plan, new Progress<OperationProgress>(), AlwaysReturn(FileConflictResolution.Abort), CancellationToken.None);

        Assert.True(result.Succeeded);
        Assert.False(File.Exists(filePath));
        Assert.True(File.Exists(Path.Combine(destination, "move-me.txt")));
    }

    [Fact]
    public async Task MoveAsync_DirectoryTree_ReportsSubtreeBytesInProgress()
    {
        var source = _temp.NewSubdir("move-tree-src");
        var subDir = Directory.CreateDirectory(Path.Combine(source, "sub")).FullName;
        var filePath = WriteFile(subDir, "nested.txt", "nested-content");
        var expectedBytes = new FileInfo(filePath).Length;
        var destination = _temp.NewSubdir("move-tree-dst");
        var plan = new CopyMovePlan(
            [ToEntry(source, isDirectory: true), ToEntry(subDir, isDirectory: true), ToEntry(filePath, isDirectory: false)],
            destination,
            OperationMode.Move);
        var reports = new List<OperationProgress>();
        var progress = new SynchronousProgress(reports.Add);

        var result = await _sut.MoveAsync(plan, progress, AlwaysReturn(FileConflictResolution.Abort), CancellationToken.None);

        Assert.True(result.Succeeded);
        Assert.False(Directory.Exists(source));
        Assert.True(File.Exists(Path.Combine(destination, Path.GetFileName(source), "sub", "nested.txt")));
        var last = Assert.Single(reports);
        Assert.Equal(1, last.FilesDone);
        Assert.Equal(1, last.FilesTotal);
        Assert.Equal(expectedBytes, last.BytesDone);
        Assert.Equal(expectedBytes, last.BytesTotal);
    }

    [Fact]
    public async Task MoveAsync_SameDirectoryDifferentEntryName_RenamesFileInPlace()
    {
        var source = _temp.NewSubdir("rename-src");
        var filePath = WriteFile(source, "old-name.txt", "payload");
        var renameEntry = ToEntry(filePath, false) with { Name = "new-name.txt" };
        var plan = new CopyMovePlan([renameEntry], source, OperationMode.Move);

        var result = await _sut.MoveAsync(plan, new Progress<OperationProgress>(), AlwaysReturn(FileConflictResolution.Abort), CancellationToken.None);

        Assert.True(result.Succeeded);
        Assert.False(File.Exists(filePath));
        Assert.True(File.Exists(Path.Combine(source, "new-name.txt")));
    }

    [Fact]
    public async Task MoveAsync_PermissionDenied_SkipsEntryAndContinuesReportingReason()
    {
        var source = _temp.NewSubdir("perm-move-src");
        var file1 = WriteFile(source, "one.txt");
        var file2 = WriteFile(source, "two.txt");
        var destination = _temp.NewSubdir("perm-move-dst");
        File.SetUnixFileMode(destination, UnixFileMode.UserRead | UnixFileMode.UserExecute);

        try
        {
            var plan = new CopyMovePlan([ToEntry(file1, false), ToEntry(file2, false)], destination, OperationMode.Move);

            var result = await _sut.MoveAsync(plan, new Progress<OperationProgress>(), AlwaysReturn(FileConflictResolution.Abort), CancellationToken.None);

            Assert.True(result.Succeeded);
            Assert.Equal(2, result.SkippedEntries.Count);
            Assert.True(File.Exists(file1));
            Assert.True(File.Exists(file2));
        }
        finally
        {
            File.SetUnixFileMode(destination, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        }
    }
}
