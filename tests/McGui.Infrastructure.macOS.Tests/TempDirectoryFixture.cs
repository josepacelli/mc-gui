using System.Runtime.Versioning;
using McGui.Core.Models;

namespace McGui.Infrastructure.macOS.Tests;

[SupportedOSPlatform("macos")]
public sealed class TempDirectoryFixture : IDisposable
{
    private readonly DirectoryInfo _root;

    public TempDirectoryFixture(string prefix) => _root = Directory.CreateTempSubdirectory(prefix);

    public string RootPath => _root.FullName;

    public string NewSubdir(string name)
    {
        var path = Path.Combine(_root.FullName, name);
        Directory.CreateDirectory(path);
        return path;
    }

    public static string WriteFile(string dir, string name, string content = "content")
    {
        var path = Path.Combine(dir, name);
        File.WriteAllText(path, content);
        return path;
    }

    public static FileEntry ToEntry(string fullPath, bool isDirectory)
    {
        var name = Path.GetFileName(fullPath);
        return new FileEntry(
            name,
            fullPath,
            isDirectory,
            isDirectory ? 0 : new FileInfo(fullPath).Length,
            DateTimeOffset.UtcNow,
            IsSymlink: false,
            IsHidden: name.StartsWith('.'));
    }

    public static FileEntry FileOf(string fullPath) => ToEntry(fullPath, isDirectory: false);

    public static FileEntry DirectoryOf(string fullPath) => ToEntry(fullPath, isDirectory: true);

    public void Dispose()
    {
        try
        {
            foreach (var dir in _root.EnumerateDirectories("*", SearchOption.AllDirectories))
            {
                try
                {
                    File.SetUnixFileMode(dir.FullName, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
                }
                catch (IOException)
                {
                }
            }

            _root.Delete(recursive: true);
        }
        catch (IOException)
        {
        }
    }
}
