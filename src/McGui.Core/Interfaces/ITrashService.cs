using McGui.Core.Models;

namespace McGui.Core.Interfaces;

/// <summary>
/// Deletes entries, moving them to the host OS trash/recycle bin when available
/// and requested, or permanently when not.
/// </summary>
public interface ITrashService
{
    OperationResult Delete(IReadOnlyList<FileEntry> entries, bool permanent);
}
