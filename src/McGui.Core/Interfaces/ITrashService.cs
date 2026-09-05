using McGui.Core.Models;

namespace McGui.Core.Interfaces;

public interface ITrashService
{
    OperationResult Delete(IReadOnlyList<FileEntry> entries, bool permanent);
}
