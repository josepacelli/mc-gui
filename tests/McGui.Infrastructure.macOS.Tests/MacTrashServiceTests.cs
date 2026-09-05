using System.Runtime.Versioning;
using McGui.Core.Models;
using McGui.Infrastructure.macOS;
using static McGui.Infrastructure.macOS.Tests.TempDirectoryFixture;

namespace McGui.Infrastructure.macOS.Tests;

[SupportedOSPlatform("macos")]
public class MacTrashServiceTests : IDisposable
{
    private readonly TempDirectoryFixture _temp = new("mcgui-trash-");

    public void Dispose() => _temp.Dispose();

    [Fact]
    public void Delete_NormalFile_MovesToHomeTrash()
    {
        var home = _temp.NewSubdir("home");
        var source = _temp.NewSubdir("source");
        var filePath = WriteFile(source, "doc.txt", "payload");
        var sut = new MacTrashService(homeDirectory: home);

        var result = sut.Delete([FileOf(filePath)], permanent: false);

        Assert.True(result.Succeeded);
        Assert.False(File.Exists(filePath));
        var trashedPath = Path.Combine(home, ".Trash", "doc.txt");
        Assert.True(File.Exists(trashedPath));
        Assert.Equal("payload", File.ReadAllText(trashedPath));
    }

    [Fact]
    public void Delete_NameCollisionInTrash_RenamesUsingFinderConvention()
    {
        var home = _temp.NewSubdir("home-collision");
        Directory.CreateDirectory(Path.Combine(home, ".Trash"));
        WriteFile(Path.Combine(home, ".Trash"), "doc.txt", "already-in-trash");
        var source = _temp.NewSubdir("source-collision");
        var filePath = WriteFile(source, "doc.txt", "new-delete");
        var sut = new MacTrashService(homeDirectory: home);

        var result = sut.Delete([FileOf(filePath)], permanent: false);

        Assert.True(result.Succeeded);
        Assert.Equal("already-in-trash", File.ReadAllText(Path.Combine(home, ".Trash", "doc.txt")));
        Assert.Equal("new-delete", File.ReadAllText(Path.Combine(home, ".Trash", "doc 2.txt")));
    }

    [Fact]
    public void Delete_Directory_MovesEntireTreeToTrash()
    {
        var home = _temp.NewSubdir("home-dir");
        var source = _temp.NewSubdir("source-dir");
        var folder = Directory.CreateDirectory(Path.Combine(source, "folder")).FullName;
        WriteFile(folder, "inner.txt", "inner");
        var sut = new MacTrashService(homeDirectory: home);

        var result = sut.Delete([DirectoryOf(folder)], permanent: false);

        Assert.True(result.Succeeded);
        Assert.False(Directory.Exists(folder));
        Assert.True(File.Exists(Path.Combine(home, ".Trash", "folder", "inner.txt")));
    }

    [Fact]
    public void Delete_PermanentTrue_DeletesWithoutUsingTrash()
    {
        var home = _temp.NewSubdir("home-permanent");
        var source = _temp.NewSubdir("source-permanent");
        var filePath = WriteFile(source, "gone.txt");
        var sut = new MacTrashService(homeDirectory: home);

        var result = sut.Delete([FileOf(filePath)], permanent: true);

        Assert.True(result.Succeeded);
        Assert.False(File.Exists(filePath));
        Assert.False(Directory.Exists(Path.Combine(home, ".Trash")));
    }

    [Fact]
    public void Delete_NoTrashAvailable_FallsBackToPermanentDelete()
    {
        var source = _temp.NewSubdir("source-no-trash");
        var filePath = WriteFile(source, "no-trash.txt");
        var sut = new MacTrashService(trashRootForPath: _ => null);

        var result = sut.Delete([FileOf(filePath)], permanent: false);

        Assert.True(result.Succeeded);
        Assert.False(File.Exists(filePath));
    }

    [Fact]
    public void Delete_TrashRootCannotBeWritten_ReportsFailureWithoutDeletingAnything()
    {
        var readOnlyParent = _temp.NewSubdir("readonly-parent");
        var source = _temp.NewSubdir("source-write-fail");
        var filePath = WriteFile(source, "protected.txt", "keep-me");
        File.SetUnixFileMode(readOnlyParent, UnixFileMode.UserRead | UnixFileMode.UserExecute);
        var unwritableTrashRoot = Path.Combine(readOnlyParent, "TrashSub");
        var sut = new MacTrashService(trashRootForPath: _ => unwritableTrashRoot);

        try
        {
            var result = sut.Delete([FileOf(filePath)], permanent: false);

            Assert.False(result.Succeeded);
            Assert.Single(result.SkippedEntries);
            Assert.Equal(filePath, result.SkippedEntries[0].Path);
            Assert.True(File.Exists(filePath));
        }
        finally
        {
            File.SetUnixFileMode(readOnlyParent, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        }
    }

    [Fact]
    public void Delete_OneEntryFailsAnotherSucceeds_ReportsFailureAndStillProcessesTheOther()
    {
        var readOnlyParent = _temp.NewSubdir("readonly-parent-batch");
        var home = _temp.NewSubdir("home-batch");
        var source = _temp.NewSubdir("source-batch");
        var blockedFile = WriteFile(source, "blocked.txt");
        var okFile = WriteFile(source, "ok.txt");
        File.SetUnixFileMode(readOnlyParent, UnixFileMode.UserRead | UnixFileMode.UserExecute);
        var unwritableTrashRoot = Path.Combine(readOnlyParent, "TrashSub");
        var callCount = 0;
        var sut = new MacTrashService(trashRootForPath: path =>
        {
            callCount++;
            return path == blockedFile ? unwritableTrashRoot : Path.Combine(home, ".Trash");
        });

        try
        {
            var result = sut.Delete([FileOf(blockedFile), FileOf(okFile)], permanent: false);

            Assert.False(result.Succeeded);
            Assert.Single(result.SkippedEntries);
            Assert.Equal(blockedFile, result.SkippedEntries[0].Path);
            Assert.True(File.Exists(blockedFile));
            Assert.False(File.Exists(okFile));
            Assert.True(File.Exists(Path.Combine(home, ".Trash", "ok.txt")));
            Assert.Equal(2, callCount);
        }
        finally
        {
            File.SetUnixFileMode(readOnlyParent, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        }
    }
}
