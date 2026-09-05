using System.Globalization;
using System.Runtime.InteropServices;
using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.Infrastructure.macOS;

public sealed class MacTrashService : ITrashService
{
    private readonly Func<string, string?> _trashRootForPath;

    public MacTrashService(string? homeDirectory = null, Func<string, string?>? trashRootForPath = null)
    {
        var effectiveHome = homeDirectory ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        _trashRootForPath = trashRootForPath ?? (path => DefaultTrashRootForPath(effectiveHome, path));
    }

    public OperationResult Delete(IReadOnlyList<FileEntry> entries, bool permanent)
    {
        var skipped = new List<(string Path, string Reason)>();

        foreach (var entry in entries)
        {
            try
            {
                if (permanent)
                {
                    PermanentlyDelete(entry);
                    continue;
                }

                var trashRoot = _trashRootForPath(entry.FullPath);
                if (trashRoot is null)
                {
                    PermanentlyDelete(entry);
                    continue;
                }

                Directory.CreateDirectory(trashRoot);
                var destination = ResolveTrashCollision(trashRoot, entry.Name);
                MoveIntoTrash(entry, destination);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                skipped.Add((entry.FullPath, ex.Message));
            }
        }

        return new OperationResult(skipped.Count == 0, skipped);
    }

    private static void MoveIntoTrash(FileEntry entry, string destination)
    {
        if (entry.IsDirectory)
        {
            Directory.Move(entry.FullPath, destination);
        }
        else
        {
            File.Move(entry.FullPath, destination);
        }
    }

    private static void PermanentlyDelete(FileEntry entry)
    {
        if (entry.IsDirectory)
        {
            Directory.Delete(entry.FullPath, recursive: true);
        }
        else
        {
            File.Delete(entry.FullPath);
        }
    }

    private static string ResolveTrashCollision(string trashRoot, string name)
    {
        var candidate = Path.Combine(trashRoot, name);
        if (!File.Exists(candidate) && !Directory.Exists(candidate))
        {
            return candidate;
        }

        var stem = Path.GetFileNameWithoutExtension(name);
        var extension = Path.GetExtension(name);
        for (var counter = 2; ; counter++)
        {
            candidate = Path.Combine(trashRoot, $"{stem} {counter}{extension}");
            if (!File.Exists(candidate) && !Directory.Exists(candidate))
            {
                return candidate;
            }
        }
    }

    private static string DefaultTrashRootForPath(string homeDirectory, string entryPath)
    {
        var homeRoot = VolumeLocator.FindDrive(homeDirectory).RootDirectory.FullName;
        var entryRoot = VolumeLocator.FindDrive(entryPath).RootDirectory.FullName;
        if (string.Equals(homeRoot, entryRoot, StringComparison.Ordinal))
        {
            return Path.Combine(homeDirectory, ".Trash");
        }

        return Path.Combine(entryRoot, ".Trashes", GetCurrentUserId().ToString(CultureInfo.InvariantCulture));
    }

    [DllImport("libc")]
    private static extern uint getuid();

    private static uint GetCurrentUserId() => OperatingSystem.IsMacOS() || OperatingSystem.IsLinux() ? getuid() : 0;
}
