using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Interfaces;
using McGui.Core.Models;
using McGui.Core.Services;

namespace McGui.App.ViewModels;

public sealed partial class PanelViewModel : ObservableObject
{
    private readonly IFileSystemService _fileSystemService;
    private readonly IPathHistoryStore _pathHistoryStore;
    private readonly PanelSide _side;
    private readonly string _fallbackHomeDirectory;
    private readonly TimeSpan _loadingIndicatorDelay;
    private readonly PanelState _state = new();

    [ObservableProperty]
    private bool isLoading;

    [ObservableProperty]
    private bool isActive;

    [ObservableProperty]
    private bool isDirectoryInaccessible;

    [ObservableProperty]
    private string? directoryErrorMessage;

    public PanelViewModel(
        IFileSystemService fileSystemService,
        IPathHistoryStore pathHistoryStore,
        PanelSide side,
        string? fallbackHomeDirectory = null,
        TimeSpan? loadingIndicatorDelay = null)
    {
        _fileSystemService = fileSystemService;
        _pathHistoryStore = pathHistoryStore;
        _side = side;
        _fallbackHomeDirectory = fallbackHomeDirectory ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        _loadingIndicatorDelay = loadingIndicatorDelay ?? TimeSpan.FromMilliseconds(500);

        var history = _pathHistoryStore.Load();
        var initialDirectory = _side == PanelSide.Left ? history.LeftPanelPath : history.RightPanelPath;
        LoadDirectorySync(initialDirectory, allowHomeFallback: true);
    }

    public string CurrentDirectory => _state.CurrentDirectory;

    public IReadOnlyList<FileEntry> Entries => _state.Entries;

    public IReadOnlyList<PanelEntryRow> DisplayEntries =>
        _state.Entries.Select(e => new PanelEntryRow(e, _state.MarkedPaths.Contains(e.FullPath))).ToList();

    public int CursorIndex
    {
        get => _state.CursorIndex;
        private set
        {
            if (_state.CursorIndex == value)
            {
                return;
            }

            _state.CursorIndex = value;
            OnPropertyChanged();
        }
    }

    public IReadOnlySet<string> MarkedPaths => _state.MarkedPaths;

    public int MarkedCount => _state.MarkedPaths.Count;

    public long MarkedSizeBytes => _state.Entries.Where(e => _state.MarkedPaths.Contains(e.FullPath)).Sum(e => e.SizeBytes);

    [RelayCommand]
    public void ToggleMark(int index)
    {
        SelectionService.Toggle(_state, index);
        NotifySelectionChanged();
        OnPropertyChanged(nameof(CursorIndex));
    }

    [RelayCommand]
    public void MarkByPattern(string pattern)
    {
        SelectionService.MarkByPattern(_state, pattern);
        NotifySelectionChanged();
    }

    [RelayCommand]
    public void UnmarkByPattern(string pattern)
    {
        SelectionService.UnmarkByPattern(_state, pattern);
        NotifySelectionChanged();
    }

    [RelayCommand]
    public void InvertMarks()
    {
        SelectionService.Invert(_state);
        NotifySelectionChanged();
    }

    private void NotifySelectionChanged()
    {
        OnPropertyChanged(nameof(MarkedPaths));
        OnPropertyChanged(nameof(MarkedCount));
        OnPropertyChanged(nameof(MarkedSizeBytes));
        OnPropertyChanged(nameof(DisplayEntries));
    }

    public async Task NavigateToAsync(string path)
    {
        using var indicatorCts = new CancellationTokenSource();
        _ = ShowLoadingIndicatorAfterDelayAsync(indicatorCts.Token);

        try
        {
            await TryLoadDirectoryAsync(path, landOnEntryName: null);
        }
        finally
        {
            indicatorCts.Cancel();
            IsLoading = false;
        }
    }

    [RelayCommand]
    public async Task NavigateToParentAsync()
    {
        var originName = Path.GetFileName(CurrentDirectory.TrimEnd(Path.DirectorySeparatorChar));
        if (string.IsNullOrEmpty(originName) || !TryGetParentDirectory(CurrentDirectory, out var parent))
        {
            return;
        }

        await NavigateToAsync(parent, landOnEntryName: originName);
    }

    private async Task NavigateToAsync(string path, string? landOnEntryName)
    {
        using var indicatorCts = new CancellationTokenSource();
        _ = ShowLoadingIndicatorAfterDelayAsync(indicatorCts.Token);

        try
        {
            await TryLoadDirectoryAsync(path, landOnEntryName);
        }
        finally
        {
            indicatorCts.Cancel();
            IsLoading = false;
        }
    }

    [RelayCommand]
    public async Task ActivateCursorEntryAsync()
    {
        if (CursorIndex < 0 || CursorIndex >= Entries.Count)
        {
            return;
        }

        var entry = Entries[CursorIndex];
        if (entry.Name == DotDot)
        {
            await NavigateToParentAsync();
        }
        else if (entry.IsDirectory)
        {
            await NavigateToAsync(entry.FullPath);
        }
    }

    [RelayCommand]
    public void MoveCursorUp() => CursorIndex = Math.Max(0, CursorIndex - 1);

    [RelayCommand]
    public void MoveCursorDown() => CursorIndex = Entries.Count == 0 ? 0 : Math.Min(Entries.Count - 1, CursorIndex + 1);

    public void MoveCursorTo(int index) =>
        CursorIndex = Entries.Count == 0 ? 0 : Math.Clamp(index, 0, Entries.Count - 1);

    [RelayCommand]
    public async Task RefreshAsync() => await TryLoadDirectoryAsync(CurrentDirectory, landOnEntryName: null);

    [RelayCommand]
    public async Task GoToHomeAsync()
    {
        IsDirectoryInaccessible = false;
        DirectoryErrorMessage = null;
        await NavigateToAsync(_fallbackHomeDirectory);
    }

    public void PersistCurrentDirectory()
    {
        var existing = _pathHistoryStore.Load();
        var updated = _side == PanelSide.Left
            ? existing with { LeftPanelPath = CurrentDirectory }
            : existing with { RightPanelPath = CurrentDirectory };
        _pathHistoryStore.Save(updated);
    }

    private const string DotDot = "..";

    private async Task<bool> TryLoadDirectoryAsync(string path, string? landOnEntryName)
    {
        try
        {
            var entries = await Task.Run(() => _fileSystemService.ListDirectory(path));
            IsDirectoryInaccessible = false;
            DirectoryErrorMessage = null;
            ApplyLoadedState(path, entries, landOnEntryName);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            IsDirectoryInaccessible = true;
            DirectoryErrorMessage = ex.Message;
            return false;
        }
    }

    private void LoadDirectorySync(string path, bool allowHomeFallback)
    {
        try
        {
            var entries = _fileSystemService.ListDirectory(path);
            ApplyLoadedState(path, entries, landOnEntryName: null);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            if (!allowHomeFallback || string.Equals(path, _fallbackHomeDirectory, StringComparison.Ordinal))
            {
                throw;
            }

            LoadDirectorySync(_fallbackHomeDirectory, allowHomeFallback: true);
        }
    }

    private void ApplyLoadedState(string path, IReadOnlyList<FileEntry> entries, string? landOnEntryName)
    {
        _state.CurrentDirectory = path;
        _state.Entries = WithDotDotEntry(path, entries);
        _state.CursorIndex = ResolveCursorIndex(landOnEntryName);
        OnPropertyChanged(nameof(CurrentDirectory));
        OnPropertyChanged(nameof(Entries));
        OnPropertyChanged(nameof(DisplayEntries));
        OnPropertyChanged(nameof(CursorIndex));
    }

    private static bool TryGetParentDirectory(string path, out string parent)
    {
        var trimmed = path.TrimEnd(Path.DirectorySeparatorChar);
        if (trimmed.Length == 0)
        {
            parent = string.Empty;
            return false;
        }

        parent = Path.GetDirectoryName(trimmed) ?? string.Empty;
        return !string.IsNullOrEmpty(parent);
    }

    private static IReadOnlyList<FileEntry> WithDotDotEntry(string currentPath, IReadOnlyList<FileEntry> entries)
    {
        if (!TryGetParentDirectory(currentPath, out var parent))
        {
            return entries;
        }

        var list = new List<FileEntry>(entries.Count + 1)
        {
            new FileEntry(DotDot, parent, IsDirectory: true, SizeBytes: 0, ModifiedUtc: DateTimeOffset.UnixEpoch, IsSymlink: false, IsHidden: false),
        };
        list.AddRange(entries);
        return list;
    }

    private int ResolveCursorIndex(string? landOnEntryName)
    {
        var firstRealIndex = 0;
        while (firstRealIndex < _state.Entries.Count && _state.Entries[firstRealIndex].Name == DotDot)
        {
            firstRealIndex++;
        }

        if (landOnEntryName is null || firstRealIndex >= _state.Entries.Count)
        {
            return firstRealIndex < _state.Entries.Count ? firstRealIndex : 0;
        }

        for (var i = firstRealIndex; i < _state.Entries.Count; i++)
        {
            if (_state.Entries[i].Name == landOnEntryName)
            {
                return i;
            }
        }

        return firstRealIndex < _state.Entries.Count ? firstRealIndex : 0;
    }

    private async Task ShowLoadingIndicatorAfterDelayAsync(CancellationToken ct)
    {
        try
        {
            await Task.Delay(_loadingIndicatorDelay, ct);
            IsLoading = true;
        }
        catch (TaskCanceledException)
        {
        }
    }
}
