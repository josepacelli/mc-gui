using McGui.Core.Models;

namespace McGui.Core.Interfaces;

/// <summary>
/// Platform implementation of file system operations used by a panel: listing,
/// directory creation, and recursive copy/move with progress and cancellation.
/// </summary>
public interface IFileSystemService
{
    IReadOnlyList<FileEntry> ListDirectory(string path);

    void CreateDirectory(string parentPath, string name);

    Task<OperationResult> CopyAsync(CopyMovePlan plan, IProgress<OperationProgress> progress, CancellationToken ct);

    Task<OperationResult> MoveAsync(CopyMovePlan plan, IProgress<OperationProgress> progress, CancellationToken ct);
}
