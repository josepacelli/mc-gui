using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.App.Tests.Fakes;

public sealed class FakeFileSystemService : IFileSystemService
{
    private readonly Dictionary<string, IReadOnlyList<FileEntry>> _directories = new();

    public TimeSpan Delay { get; set; } = TimeSpan.Zero;

    public void AddDirectory(string path, params FileEntry[] entries) => _directories[path] = entries;

    public IReadOnlyList<FileEntry> ListDirectory(string path)
    {
        if (Delay > TimeSpan.Zero)
        {
            Thread.Sleep(Delay);
        }

        if (!_directories.TryGetValue(path, out var entries))
        {
            throw new DirectoryNotFoundException($"Directory not found: {path}");
        }

        return entries;
    }

    public void CreateDirectory(string parentPath, string name) => throw new NotSupportedException();

    public Task<OperationResult> CopyAsync(
        CopyMovePlan plan,
        IProgress<OperationProgress> progress,
        Func<string, FileConflictResolution> resolveConflict,
        CancellationToken ct) =>
        throw new NotSupportedException();

    public Task<OperationResult> MoveAsync(
        CopyMovePlan plan,
        IProgress<OperationProgress> progress,
        Func<string, FileConflictResolution> resolveConflict,
        CancellationToken ct) =>
        throw new NotSupportedException();
}
