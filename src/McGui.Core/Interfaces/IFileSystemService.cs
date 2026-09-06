using McGui.Core.Models;

namespace McGui.Core.Interfaces;

public interface IFileSystemService
{
    IReadOnlyList<FileEntry> ListDirectory(string path);

    void CreateDirectory(string parentPath, string name);

    Task<OperationResult> CopyAsync(
        CopyMovePlan plan,
        IProgress<OperationProgress> progress,
        Func<string, FileConflictResolution> resolveConflict,
        CancellationToken ct,
        CopyMoveOptions options = default(CopyMoveOptions));

    Task<OperationResult> MoveAsync(
        CopyMovePlan plan,
        IProgress<OperationProgress> progress,
        Func<string, FileConflictResolution> resolveConflict,
        CancellationToken ct,
        CopyMoveOptions options = default(CopyMoveOptions));
}
