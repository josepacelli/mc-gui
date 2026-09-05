using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.Core.Services;

/// <summary>
/// Builds a <see cref="CopyMovePlan"/> from marked entries: expands directories
/// recursively via the injected <see cref="IFileSystemService"/> and rejects
/// circular copy/move and moving the other panel's current directory
/// (DPC-18, DPC-22, DPC-23) before anything is written.
/// </summary>
public sealed class CopyMovePlanner(IFileSystemService fileSystemService)
{
    private readonly IFileSystemService _fileSystemService = fileSystemService;

    /// <param name="otherPanelCurrentDir">
    /// Current directory shown in the opposite panel, used to enforce DPC-23. Null when
    /// the caller has no opposite panel to check against (e.g. a single-panel context).
    /// SPEC_DEVIATION: design.md's Components section lists Build(sources, destinationDir, mode)
    /// without this parameter; tasks.md's T7 breakdown requires it to implement DPC-23, so the
    /// task definition (later and more concrete) is followed here.
    /// </param>
    public CopyMovePlan Build(
        IReadOnlyList<FileEntry> sources,
        string destinationDir,
        OperationMode mode,
        string? otherPanelCurrentDir = null)
    {
        var normalizedDestination = NormalizePath(destinationDir);

        foreach (var source in sources)
        {
            if (!source.IsDirectory)
            {
                continue;
            }

            var normalizedSource = NormalizePath(source.FullPath);

            // DPC-18 (Copy) / DPC-22 (Move): destination is the source itself or one of its subdirectories.
            if (IsSameOrSubdirectory(normalizedDestination, normalizedSource))
            {
                var verb = mode == OperationMode.Copy ? "copy" : "move";
                throw new CopyMovePlanValidationException(
                    $"Cannot {verb} '{source.FullPath}' into itself or one of its own subdirectories " +
                    $"(circular {verb}): destination '{destinationDir}' is inside the source.");
            }

            // DPC-23 (Move): the entry being moved is the current directory shown in the other panel.
            if (mode == OperationMode.Move
                && otherPanelCurrentDir is not null
                && string.Equals(NormalizePath(otherPanelCurrentDir), normalizedSource, StringComparison.Ordinal))
            {
                throw new CopyMovePlanValidationException(
                    $"Cannot move '{source.FullPath}': it is the current directory shown in the other panel.");
            }
        }

        var expanded = new List<FileEntry>();
        foreach (var source in sources)
        {
            expanded.Add(source);
            if (source.IsDirectory)
            {
                ExpandRecursively(source.FullPath, expanded);
            }
        }

        return new CopyMovePlan(expanded, destinationDir, mode);
    }

    private void ExpandRecursively(string directoryPath, List<FileEntry> results)
    {
        foreach (var entry in _fileSystemService.ListDirectory(directoryPath))
        {
            results.Add(entry);
            if (entry.IsDirectory)
            {
                ExpandRecursively(entry.FullPath, results);
            }
        }
    }

    private static bool IsSameOrSubdirectory(string destination, string source)
    {
        if (string.Equals(destination, source, StringComparison.Ordinal))
        {
            return true;
        }

        var sourceWithSeparator = source.EndsWith('/') ? source : source + "/";
        return destination.StartsWith(sourceWithSeparator, StringComparison.Ordinal);
    }

    private static string NormalizePath(string path) => path.TrimEnd('/');
}
