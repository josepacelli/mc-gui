using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Interfaces;
using McGui.Core.Models;
using McGui.Core.Services;

namespace McGui.App.ViewModels;

public sealed partial class MainWindowViewModel : ObservableObject
{
    private readonly IFileSystemService _fileSystemService;
    private readonly ITrashService _trashService;
    private readonly CopyMovePlanner _planner;
    private readonly IViewerService _viewerService;
    private readonly IEditorService _editorService;

    [ObservableProperty]
    private PanelViewModel activePanel;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsSystemThemeChecked))]
    [NotifyPropertyChangedFor(nameof(IsLightThemeChecked))]
    [NotifyPropertyChangedFor(nameof(IsDarkThemeChecked))]
    private ThemePreference currentTheme = ThemePreference.System;

    public MainWindowViewModel(
        IFileSystemService fileSystemService,
        ITrashService trashService,
        IPathHistoryStore pathHistoryStore,
        IViewerService viewerService,
        IEditorService editorService)
    {
        _fileSystemService = fileSystemService;
        _trashService = trashService;
        _planner = new CopyMovePlanner(fileSystemService);
        _viewerService = viewerService;
        _editorService = editorService;
        ConflictPrompt = new AutoSkipConflictPrompt();
        SaveChangesPrompt = new AutoSaveChangesPrompt();
        LeftPanel = new PanelViewModel(fileSystemService, pathHistoryStore, PanelSide.Left);
        RightPanel = new PanelViewModel(fileSystemService, pathHistoryStore, PanelSide.Right);
        LeftPanel.IsActive = true;
        activePanel = LeftPanel;
    }

    public PanelViewModel LeftPanel { get; }

    public PanelViewModel RightPanel { get; }

    public IConflictPrompt ConflictPrompt { get; set; }

    public ISaveChangesPrompt SaveChangesPrompt { get; set; }

    public event EventHandler<CopyMoveDialogViewModel>? CopyMoveRequested;

    public event EventHandler<DeleteConfirmDialogViewModel>? DeleteRequested;

    public event EventHandler<MkdirDialogViewModel>? MkdirRequested;

    public event EventHandler<ViewerViewModel>? ViewRequested;

    public event EventHandler<EditorWindowViewModel>? EditRequested;

    public bool IsMacOS => OperatingSystem.IsMacOS();

    public bool IsSystemThemeChecked => CurrentTheme == ThemePreference.System;

    public bool IsLightThemeChecked => CurrentTheme == ThemePreference.Light;

    public bool IsDarkThemeChecked => CurrentTheme == ThemePreference.Dark;

    [RelayCommand]
    public void SetTheme(ThemePreference preference) => CurrentTheme = preference;

    [RelayCommand]
    public void CycleTheme() =>
        CurrentTheme = CurrentTheme switch
        {
            ThemePreference.System => ThemePreference.Light,
            ThemePreference.Light => ThemePreference.Dark,
            _ => ThemePreference.System,
        };

    [RelayCommand]
    public void SwitchActivePanel()
    {
        var next = ReferenceEquals(ActivePanel, LeftPanel) ? RightPanel : LeftPanel;
        ActivePanel.IsActive = false;
        next.IsActive = true;
        ActivePanel = next;
    }

    [RelayCommand]
    public void RequestCopy() => RequestCopyOrMove(OperationMode.Copy);

    [RelayCommand]
    public void RequestMove() => RequestCopyOrMove(OperationMode.Move);

    [RelayCommand]
    public async Task RescanActivePanelAsync() => await ActivePanel.RefreshCommand.ExecuteAsync(null);

    [RelayCommand]
    public void SelectAll() => ActivePanel.MarkByPattern("*");

    [RelayCommand]
    public void UnselectAll() => ActivePanel.UnmarkByPattern("*");

    [RelayCommand]
    public void InvertSelection() => ActivePanel.InvertMarks();

    private void RequestCopyOrMove(OperationMode mode)
    {
        var sources = GetOperationSources(ActivePanel);
        if (sources.Count == 0)
        {
            return;
        }

        var otherPanel = ReferenceEquals(ActivePanel, LeftPanel) ? RightPanel : LeftPanel;
        var destination = mode == OperationMode.Move && sources.Count == 1
            ? ParentDirectoryOf(sources[0].FullPath)
            : otherPanel.CurrentDirectory;

        var dialogViewModel = new CopyMoveDialogViewModel(
            _fileSystemService,
            _planner,
            ConflictPrompt,
            sources,
            destination,
            mode,
            otherPanel.CurrentDirectory);

        CopyMoveRequested?.Invoke(this, dialogViewModel);
    }

    [RelayCommand]
    public void RequestDelete()
    {
        var sources = GetOperationSources(ActivePanel);
        if (sources.Count == 0)
        {
            return;
        }

        var dialogViewModel = new DeleteConfirmDialogViewModel(_trashService, sources);
        DeleteRequested?.Invoke(this, dialogViewModel);
    }

    [RelayCommand]
    public void RequestMkdir()
    {
        var dialogViewModel = new MkdirDialogViewModel(_fileSystemService, ActivePanel.CurrentDirectory);
        MkdirRequested?.Invoke(this, dialogViewModel);
    }

    private static IReadOnlyList<FileEntry> GetOperationSources(PanelViewModel panel)
    {
        if (panel.MarkedPaths.Count > 0)
        {
            return panel.Entries
                .Where(e => panel.MarkedPaths.Contains(e.FullPath) && e.Name != "..")
                .ToList();
        }

        if (panel.CursorIndex >= 0 && panel.CursorIndex < panel.Entries.Count)
        {
            var cursor = panel.Entries[panel.CursorIndex];
            return cursor.Name == ".." ? Array.Empty<FileEntry>() : new[] { cursor };
        }

        return Array.Empty<FileEntry>();
    }

    private static string ParentDirectoryOf(string fullPath) =>
        Path.GetDirectoryName(fullPath.TrimEnd(Path.DirectorySeparatorChar)) ?? fullPath;

    private sealed class AutoSkipConflictPrompt : IConflictPrompt
    {
        public Task<ConflictPromptResult> PromptAsync(string destinationPath) =>
            Task.FromResult(new ConflictPromptResult(FileConflictResolution.Skip, ApplyToAll: true));
    }

    private sealed class AutoSaveChangesPrompt : ISaveChangesPrompt
    {
        public Task<SaveChangesResult> PromptAsync(string fileName) =>
            Task.FromResult(SaveChangesResult.Discard);
    }

    [RelayCommand]
    public void RequestEdit()
    {
        var entries = GetOperationSources(ActivePanel)
            .Where(e => !e.IsDirectory)
            .ToList();
        if (entries.Count == 0)
        {
            return;
        }

        var editorViewModel = new EditorWindowViewModel(_editorService, SaveChangesPrompt)
        {
            InitialOpenPaths = entries.Select(e => e.FullPath).ToList(),
        };
        EditRequested?.Invoke(this, editorViewModel);
    }

    [RelayCommand]
    public void RequestView()
    {
        var sources = GetOperationSources(ActivePanel);
        if (sources.Count == 0)
        {
            return;
        }

        // Only allow viewing files, not directories
        var fileEntry = sources.FirstOrDefault(e => !e.IsDirectory);
        if (fileEntry == null)
        {
            return;
        }

        var viewerViewModel = new ViewerViewModel(_viewerService);
        viewerViewModel.FilePath = fileEntry.FullPath;
        
        ViewRequested?.Invoke(this, viewerViewModel);
    }
}
