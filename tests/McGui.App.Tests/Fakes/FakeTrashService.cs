using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.App.Tests.Fakes;

public sealed class FakeTrashService : ITrashService
{
    public List<(IReadOnlyList<FileEntry> Entries, bool Permanent)> Calls { get; } = [];

    public OperationResult Delete(IReadOnlyList<FileEntry> entries, bool permanent)
    {
        Calls.Add((entries, permanent));
        return new OperationResult(true, Array.Empty<(string Path, string Reason)>());
    }
}
