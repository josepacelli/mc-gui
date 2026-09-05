using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.Core.Tests.Fakes;

public sealed class FakeFileSystemService : IFileSystemService
{
    private readonly Dictionary<string, IReadOnlyList<FileEntry>> _directories = new();

    public void AddDirectory(string path, params FileEntry[] entries) => _directories[path] = entries;

    public IReadOnlyList<FileEntry> ListDirectory(string path) =>
        _directories.TryGetValue(path, out var entries) ? entries : Array.Empty<FileEntry>();

    public void CreateDirectory(string parentPath, string name) => throw new NotSupportedException();

    public Task<OperationResult> CopyAsync(CopyMovePlan plan, IProgress<OperationProgress> progress, CancellationToken ct) =>
        throw new NotSupportedException();

    public Task<OperationResult> MoveAsync(CopyMovePlan plan, IProgress<OperationProgress> progress, CancellationToken ct) =>
        throw new NotSupportedException();
}
