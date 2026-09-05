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

    [ObservableProperty]
    private PanelViewModel activePanel;

    public MainWindowViewModel(IFileSystemService fileSystemService, ITrashService trashService, IPathHistoryStore pathHistoryStore)
    {
        _fileSystemService = fileSystemService;
        _trashService = trashService;
        _planner = new CopyMovePlanner(fileSystemService);
        ConflictPrompt = new AutoSkipConflictPrompt();
        LeftPanel = new PanelViewModel(fileSystemService, pathHistoryStore, PanelSide.Left);
        RightPanel = new PanelViewModel(fileSystemService, pathHistoryStore, PanelSide.Right);
        LeftPanel.IsActive = true;
        activePanel = LeftPanel;
    }

    public PanelViewModel LeftPanel { get; }

    public PanelViewModel RightPanel { get; }

    public IConflictPrompt ConflictPrompt { get; set; }

    public event EventHandler<CopyMoveDialogViewModel>? CopyMoveRequested;

    public event EventHandler<DeleteConfirmDialogViewModel>? DeleteRequested;

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

    private static IReadOnlyList<FileEntry> GetOperationSources(PanelViewModel panel)
    {
        if (panel.MarkedPaths.Count > 0)
        {
            return panel.Entries.Where(e => panel.MarkedPaths.Contains(e.FullPath)).ToList();
        }

        if (panel.CursorIndex >= 0 && panel.CursorIndex < panel.Entries.Count)
        {
            return new[] { panel.Entries[panel.CursorIndex] };
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
}
