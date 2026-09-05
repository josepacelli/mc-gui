using McGui.Core.Models;

namespace McGui.Core.Interfaces;

public interface IFileSystemService
{
    IReadOnlyList<FileEntry> ListDirectory(string path);

    void CreateDirectory(string parentPath, string name);

    Task<OperationResult> CopyAsync(CopyMovePlan plan, IProgress<OperationProgress> progress, CancellationToken ct);

    Task<OperationResult> MoveAsync(CopyMovePlan plan, IProgress<OperationProgress> progress, CancellationToken ct);
}
