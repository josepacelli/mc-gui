using McGui.Core.Models;
using McGui.Core.Services;
using McGui.Core.Tests.Fakes;

namespace McGui.Core.Tests.Services;

public class CopyMovePlannerTests
{
    private static FileEntry File(string path) =>
        new(Path.GetFileName(path), path, IsDirectory: false, SizeBytes: 1, ModifiedUtc: DateTimeOffset.UnixEpoch, IsSymlink: false, IsHidden: false);

    private static FileEntry Dir(string path) =>
        new(Path.GetFileName(path), path, IsDirectory: true, SizeBytes: 0, ModifiedUtc: DateTimeOffset.UnixEpoch, IsSymlink: false, IsHidden: false);

    // Happy path: a single file with no directories involved produces a plan with
    // exactly that entry and the requested destination/mode, no expansion needed.
    [Fact]
    public void Build_HappyPath_SingleFile_ReturnsPlanUnchanged()
    {
        var planner = new CopyMovePlanner(new FakeFileSystemService());
        var file = File("/left/report.txt");

        var plan = planner.Build([file], "/right", OperationMode.Copy);

        Assert.Single(plan.Sources);
        Assert.Equal(file, plan.Sources[0]);
        Assert.Equal("/right", plan.DestinationDirectory);
        Assert.Equal(OperationMode.Copy, plan.Mode);
    }

    // Directories are expanded recursively via IFileSystemService: every nested file
    // and subdirectory ends up in the plan's Sources.
    [Fact]
    public void Build_DirectorySource_ExpandsRecursively()
    {
        var fs = new FakeFileSystemService();
        var sub = Dir("/left/src/sub");
        var file1 = File("/left/src/file1.txt");
        var file2 = File("/left/src/sub/file2.txt");
        fs.AddDirectory("/left/src", file1, sub);
        fs.AddDirectory("/left/src/sub", file2);
        var planner = new CopyMovePlanner(fs);
        var srcDir = Dir("/left/src");

        var plan = planner.Build([srcDir], "/right", OperationMode.Copy);

        Assert.Equal(4, plan.Sources.Count);
        Assert.Contains(srcDir, plan.Sources);
        Assert.Contains(file1, plan.Sources);
        Assert.Contains(sub, plan.Sources);
        Assert.Contains(file2, plan.Sources);
    }

    // DPC-18: copying into the source path itself or a subdirectory of it is rejected
    // before anything is written, with an error message identifying the circular copy.
    [Fact]
    public void Build_Copy_DestinationIsSubdirectoryOfSource_ThrowsCircularCopyError()
    {
        var fs = new FakeFileSystemService();
        var planner = new CopyMovePlanner(fs);
        var srcDir = Dir("/left/src");

        var ex = Assert.Throws<CopyMovePlanValidationException>(
            () => planner.Build([srcDir], "/left/src/sub", OperationMode.Copy));

        Assert.Contains("circular", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // DPC-22: moving a directory into itself is rejected with an error message.
    [Fact]
    public void Build_Move_DestinationIsSourceItself_ThrowsCircularMoveError()
    {
        var fs = new FakeFileSystemService();
        var planner = new CopyMovePlanner(fs);
        var srcDir = Dir("/left/src");

        var ex = Assert.Throws<CopyMovePlanValidationException>(
            () => planner.Build([srcDir], "/left/src", OperationMode.Move));

        Assert.Contains("circular", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // DPC-23: moving the entry that is the current directory shown in the other panel
    // is blocked with an explanation, before the operation starts.
    [Fact]
    public void Build_Move_SourceIsOtherPanelCurrentDirectory_ThrowsBlockedError()
    {
        var fs = new FakeFileSystemService();
        var planner = new CopyMovePlanner(fs);
        var srcDir = Dir("/left/foo");

        var ex = Assert.Throws<CopyMovePlanValidationException>(
            () => planner.Build([srcDir], "/right", OperationMode.Move, otherPanelCurrentDir: "/left/foo"));

        Assert.Contains("other panel", ex.Message, StringComparison.OrdinalIgnoreCase);
    }
}
