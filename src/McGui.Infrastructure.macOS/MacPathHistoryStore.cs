using System.Text.Json;
using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.Infrastructure.macOS;

public sealed class MacPathHistoryStore : IPathHistoryStore
{
    private readonly string _stateFilePath;
    private readonly string _fallbackHomeDirectory;

    public MacPathHistoryStore(string? stateFilePath = null, string? fallbackHomeDirectory = null)
    {
        _fallbackHomeDirectory = fallbackHomeDirectory ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        _stateFilePath = stateFilePath ?? DefaultStateFilePath(_fallbackHomeDirectory);
    }

    public PanelPathHistory Load()
    {
        var loaded = TryReadFromDisk();
        var left = loaded is not null && Directory.Exists(loaded.LeftPanelPath) ? loaded.LeftPanelPath : _fallbackHomeDirectory;
        var right = loaded is not null && Directory.Exists(loaded.RightPanelPath) ? loaded.RightPanelPath : _fallbackHomeDirectory;
        return new PanelPathHistory(left, right);
    }

    public void Save(PanelPathHistory history)
    {
        var directory = Path.GetDirectoryName(_stateFilePath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var json = JsonSerializer.Serialize(history);
        File.WriteAllText(_stateFilePath, json);
    }

    private PanelPathHistory? TryReadFromDisk()
    {
        if (!File.Exists(_stateFilePath))
        {
            return null;
        }

        try
        {
            var json = File.ReadAllText(_stateFilePath);
            return JsonSerializer.Deserialize<PanelPathHistory>(json);
        }
        catch (Exception ex) when (ex is IOException or JsonException)
        {
            return null;
        }
    }

    private static string DefaultStateFilePath(string homeDirectory) =>
        Path.Combine(homeDirectory, "Library", "Application Support", "mc-gui", "state.json");
}
