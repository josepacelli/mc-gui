using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.Infrastructure.macOS;

public sealed class MacFileSystemService : IFileSystemService
{
    private readonly Func<string, long> _availableFreeSpaceForPath;

    public MacFileSystemService(Func<string, long>? availableFreeSpaceForPath = null)
    {
        _availableFreeSpaceForPath = availableFreeSpaceForPath ?? (path => VolumeLocator.FindDrive(path).AvailableFreeSpace);
    }

    public IReadOnlyList<FileEntry> ListDirectory(string path)
    {
        var result = new List<FileEntry>();
        foreach (var fullPath in Directory.EnumerateFileSystemEntries(path))
        {
            result.Add(BuildEntry(fullPath));
        }

        return result;
    }

    public void CreateDirectory(string parentPath, string name)
    {
        var invalidChars = Path.GetInvalidFileNameChars();
        var invalidIndex = name.IndexOfAny(invalidChars);
        if (invalidIndex >= 0)
        {
            throw new ArgumentException(
                $"Name '{name}' contains an invalid character for this file system: '{name[invalidIndex]}'.",
                nameof(name));
        }

        var fullPath = Path.Combine(parentPath, name);
        if (Directory.Exists(fullPath) || File.Exists(fullPath))
        {
            throw new IOException($"An entry named '{name}' already exists in '{parentPath}'.");
        }

        Directory.CreateDirectory(fullPath);
    }

    public Task<OperationResult> CopyAsync(
        CopyMovePlan plan,
        IProgress<OperationProgress> progress,
        Func<string, FileConflictResolution> resolveConflict,
        CancellationToken ct) =>
        Task.Run(() => ExecuteCopy(plan, progress, resolveConflict, ct), CancellationToken.None);

    public Task<OperationResult> MoveAsync(
        CopyMovePlan plan,
        IProgress<OperationProgress> progress,
        Func<string, FileConflictResolution> resolveConflict,
        CancellationToken ct) =>
        Task.Run(() => ExecuteMove(plan, progress, resolveConflict, ct), CancellationToken.None);

    private OperationResult ExecuteCopy(
        CopyMovePlan plan,
        IProgress<OperationProgress> progress,
        Func<string, FileConflictResolution> resolveConflict,
        CancellationToken ct)
    {
        EnsureSufficientSpace(plan);

        var skipped = new List<(string Path, string Reason)>();
        var destinationByFullPath = new Dictionary<string, string>(StringComparer.Ordinal);
        var filesTotal = plan.Sources.Count;
        var bytesTotal = plan.Sources.Where(e => !e.IsDirectory).Sum(e => e.SizeBytes);
        var filesDone = 0;
        var bytesDone = 0L;

        foreach (var entry in plan.Sources)
        {
            if (ct.IsCancellationRequested)
            {
                progress.Report(new OperationProgress(entry.Name, filesDone, filesTotal, bytesDone, bytesTotal, IsCancelled: true));
                return new OperationResult(true, skipped);
            }

            var parentPath = Path.GetDirectoryName(entry.FullPath.TrimEnd(Path.DirectorySeparatorChar));
            var destinationDir = parentPath is not null && destinationByFullPath.TryGetValue(parentPath, out var mappedParent)
                ? mappedParent
                : plan.DestinationDirectory;
            var destinationPath = Path.Combine(destinationDir, entry.Name);

            if (entry.IsDirectory)
            {
                destinationByFullPath[entry.FullPath] = destinationPath;
                Directory.CreateDirectory(destinationPath);
                filesDone++;
                progress.Report(new OperationProgress(entry.Name, filesDone, filesTotal, bytesDone, bytesTotal, IsCancelled: false));
                continue;
            }

            try
            {
                if (File.Exists(destinationPath))
                {
                    var resolution = resolveConflict(destinationPath);
                    switch (resolution)
                    {
                        case FileConflictResolution.Skip:
                            filesDone++;
                            progress.Report(new OperationProgress(entry.Name, filesDone, filesTotal, bytesDone, bytesTotal, IsCancelled: false));
                            continue;
                        case FileConflictResolution.Abort:
                            skipped.Add((entry.FullPath, "aborted by user at conflict prompt"));
                            return new OperationResult(false, skipped);
                        case FileConflictResolution.Rename:
                            destinationPath = ResolveNonCollidingPath(destinationPath);
                            File.Copy(entry.FullPath, destinationPath, overwrite: false);
                            break;
                        case FileConflictResolution.Overwrite:
                        default:
                            File.Copy(entry.FullPath, destinationPath, overwrite: true);
                            break;
                    }
                }
                else
                {
                    File.Copy(entry.FullPath, destinationPath, overwrite: false);
                }

                bytesDone += entry.SizeBytes;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                skipped.Add((entry.FullPath, ex.Message));
            }

            filesDone++;
            progress.Report(new OperationProgress(entry.Name, filesDone, filesTotal, bytesDone, bytesTotal, IsCancelled: false));
        }

        return new OperationResult(true, skipped);
    }

    private OperationResult ExecuteMove(
        CopyMovePlan plan,
        IProgress<OperationProgress> progress,
        Func<string, FileConflictResolution> resolveConflict,
        CancellationToken ct)
    {
        EnsureSufficientSpace(plan);

        var sourcePaths = new HashSet<string>(plan.Sources.Select(e => e.FullPath), StringComparer.Ordinal);
        var topLevel = plan.Sources
            .Where(e => Path.GetDirectoryName(e.FullPath.TrimEnd(Path.DirectorySeparatorChar)) is not { } parent || !sourcePaths.Contains(parent))
            .ToList();

        var skipped = new List<(string Path, string Reason)>();
        var filesTotal = topLevel.Count;
        var bytesTotal = plan.Sources.Where(e => !e.IsDirectory).Sum(e => e.SizeBytes);
        var filesDone = 0;
        var bytesDone = 0L;

        foreach (var entry in topLevel)
        {
            if (ct.IsCancellationRequested)
            {
                progress.Report(new OperationProgress(entry.Name, filesDone, filesTotal, bytesDone, bytesTotal, IsCancelled: true));
                return new OperationResult(true, skipped);
            }

            var destinationPath = Path.Combine(plan.DestinationDirectory, entry.Name);
            var entrySize = SubtreeSize(plan.Sources, entry);

            try
            {
                if (File.Exists(destinationPath) || Directory.Exists(destinationPath))
                {
                    var resolution = resolveConflict(destinationPath);
                    switch (resolution)
                    {
                        case FileConflictResolution.Skip:
                            filesDone++;
                            progress.Report(new OperationProgress(entry.Name, filesDone, filesTotal, bytesDone, bytesTotal, IsCancelled: false));
                            continue;
                        case FileConflictResolution.Abort:
                            skipped.Add((entry.FullPath, "aborted by user at conflict prompt"));
                            return new OperationResult(false, skipped);
                        case FileConflictResolution.Rename:
                            destinationPath = ResolveNonCollidingPath(destinationPath);
                            MoveEntry(entry, destinationPath);
                            break;
                        case FileConflictResolution.Overwrite:
                        default:
                            DeleteExisting(destinationPath);
                            MoveEntry(entry, destinationPath);
                            break;
                    }
                }
                else
                {
                    MoveEntry(entry, destinationPath);
                }

                bytesDone += entrySize;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                skipped.Add((entry.FullPath, ex.Message));
            }

            filesDone++;
            progress.Report(new OperationProgress(entry.Name, filesDone, filesTotal, bytesDone, bytesTotal, IsCancelled: false));
        }

        return new OperationResult(true, skipped);
    }

    private static void MoveEntry(FileEntry entry, string destinationPath)
    {
        if (entry.IsDirectory)
        {
            try
            {
                Directory.Move(entry.FullPath, destinationPath);
            }
            catch (IOException)
            {
                CopyDirectoryRecursively(entry.FullPath, destinationPath);
                Directory.Delete(entry.FullPath, recursive: true);
            }
        }
        else
        {
            try
            {
                File.Move(entry.FullPath, destinationPath);
            }
            catch (IOException)
            {
                File.Copy(entry.FullPath, destinationPath, overwrite: false);
                File.Delete(entry.FullPath);
            }
        }
    }

    private static void CopyDirectoryRecursively(string sourceDir, string destinationDir)
    {
        Directory.CreateDirectory(destinationDir);
        foreach (var filePath in Directory.EnumerateFiles(sourceDir))
        {
            File.Copy(filePath, Path.Combine(destinationDir, Path.GetFileName(filePath)), overwrite: false);
        }

        foreach (var subDir in Directory.EnumerateDirectories(sourceDir))
        {
            CopyDirectoryRecursively(subDir, Path.Combine(destinationDir, Path.GetFileName(subDir)));
        }
    }

    private static void DeleteExisting(string path)
    {
        if (Directory.Exists(path))
        {
            Directory.Delete(path, recursive: true);
        }
        else if (File.Exists(path))
        {
            File.Delete(path);
        }
    }

    private static long SubtreeSize(IReadOnlyList<FileEntry> allEntries, FileEntry root)
    {
        if (!root.IsDirectory)
        {
            return root.SizeBytes;
        }

        var prefix = root.FullPath.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return allEntries.Where(e => !e.IsDirectory && e.FullPath.StartsWith(prefix, StringComparison.Ordinal)).Sum(e => e.SizeBytes);
    }

    private void EnsureSufficientSpace(CopyMovePlan plan)
    {
        var required = plan.Sources.Where(e => !e.IsDirectory).Sum(e => e.SizeBytes);
        var available = _availableFreeSpaceForPath(plan.DestinationDirectory);
        if (available < required)
        {
            throw new InsufficientDiskSpaceException(required, available);
        }
    }

    private static string ResolveNonCollidingPath(string path)
    {
        var directory = Path.GetDirectoryName(path) ?? "";
        var stem = Path.GetFileNameWithoutExtension(path);
        var extension = Path.GetExtension(path);
        for (var counter = 2; ; counter++)
        {
            var candidate = Path.Combine(directory, $"{stem} {counter}{extension}");
            if (!File.Exists(candidate) && !Directory.Exists(candidate))
            {
                return candidate;
            }
        }
    }

    private static FileEntry BuildEntry(string fullPath)
    {
        var name = Path.GetFileName(fullPath);
        var isSymlink = new FileInfo(fullPath).LinkTarget is not null;
        var isDirectory = Directory.Exists(fullPath);
        long sizeBytes = 0;
        var modifiedUtc = DateTime.UnixEpoch;

        if (isDirectory)
        {
            modifiedUtc = Directory.GetLastWriteTimeUtc(fullPath);
        }
        else
        {
            var fileInfo = new FileInfo(fullPath);
            if (fileInfo.Exists)
            {
                sizeBytes = fileInfo.Length;
                modifiedUtc = fileInfo.LastWriteTimeUtc;
            }
        }

        var isHidden = name.StartsWith('.');
        return new FileEntry(name, fullPath, isDirectory, sizeBytes, new DateTimeOffset(modifiedUtc, TimeSpan.Zero), isSymlink, isHidden);
    }
}
