using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.Core.Services;

public sealed class CopyMovePlanner(IFileSystemService fileSystemService)
{
    private readonly IFileSystemService _fileSystemService = fileSystemService;

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

            if (IsSameOrSubdirectory(normalizedDestination, normalizedSource))
            {
                var verb = mode == OperationMode.Copy ? "copy" : "move";
                throw new CopyMovePlanValidationException(
                    $"Cannot {verb} '{source.FullPath}' into itself or one of its own subdirectories " +
                    $"(circular {verb}): destination '{destinationDir}' is inside the source.");
            }

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
