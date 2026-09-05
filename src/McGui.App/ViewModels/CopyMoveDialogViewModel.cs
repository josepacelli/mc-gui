using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Interfaces;
using McGui.Core.Models;
using McGui.Core.Services;
using McGui.Infrastructure.macOS;

namespace McGui.App.ViewModels;

public sealed partial class CopyMoveDialogViewModel : ObservableObject
{
    private readonly IFileSystemService _fileSystemService;
    private readonly CopyMovePlanner _planner;
    private readonly IConflictPrompt _conflictPrompt;
    private readonly string? _otherPanelCurrentDir;
    private FileConflictResolution? _applyToAllResolution;
    private CancellationTokenSource? _cts;

    public CopyMoveDialogViewModel(
        IFileSystemService fileSystemService,
        CopyMovePlanner planner,
        IConflictPrompt conflictPrompt,
        IReadOnlyList<FileEntry> sources,
        string destinationDirectory,
        OperationMode mode,
        string? otherPanelCurrentDir)
    {
        _fileSystemService = fileSystemService;
        _planner = planner;
        _conflictPrompt = conflictPrompt;
        _otherPanelCurrentDir = otherPanelCurrentDir;
        Sources = sources;
        Mode = mode;
        this.destinationDirectory = destinationDirectory;
        newName = Sources.Count == 1 ? Sources[0].Name : string.Empty;
    }

    public IReadOnlyList<FileEntry> Sources { get; }

    public OperationMode Mode { get; }

    public bool CanRename => Mode == OperationMode.Move && Sources.Count == 1;

    [ObservableProperty]
    private string destinationDirectory;

    [ObservableProperty]
    private string newName;

    [ObservableProperty]
    private string? errorMessage;

    [ObservableProperty]
    private OperationProgress? lastProgress;

    [ObservableProperty]
    private bool isCompleted;

    public bool HasError => !string.IsNullOrEmpty(ErrorMessage);

    public bool HasProgress => LastProgress is not null;

    public string ProgressFileName => LastProgress?.CurrentFileName ?? string.Empty;

    public int ProgressFilesDone => LastProgress?.FilesDone ?? 0;

    public OperationResult? LastResult { get; private set; }

    public event EventHandler<OperationProgress>? ProgressReported;

    partial void OnErrorMessageChanged(string? value) => OnPropertyChanged(nameof(HasError));

    partial void OnLastProgressChanged(OperationProgress? value)
    {
        OnPropertyChanged(nameof(HasProgress));
        OnPropertyChanged(nameof(ProgressFileName));
        OnPropertyChanged(nameof(ProgressFilesDone));
    }

    [RelayCommand]
    private async Task ConfirmAsync()
    {
        ErrorMessage = null;

        var effectiveSources = CanRename && !string.Equals(NewName, Sources[0].Name, StringComparison.Ordinal)
            ? new List<FileEntry> { Sources[0] with { Name = NewName } }
            : Sources;

        CopyMovePlan plan;
        try
        {
            plan = _planner.Build(effectiveSources, DestinationDirectory, Mode, _otherPanelCurrentDir);
        }
        catch (CopyMovePlanValidationException ex)
        {
            ErrorMessage = ex.Message;
            return;
        }

        using var cts = new CancellationTokenSource();
        _cts = cts;
        _applyToAllResolution = null;
        var progress = new SynchronousProgress<OperationProgress>(ReportProgress);

        try
        {
            LastResult = Mode == OperationMode.Copy
                ? await _fileSystemService.CopyAsync(plan, progress, ResolveConflict, cts.Token)
                : await _fileSystemService.MoveAsync(plan, progress, ResolveConflict, cts.Token);
            IsCompleted = true;
        }
        catch (InsufficientDiskSpaceException ex)
        {
            ErrorMessage = $"Insufficient disk space: required {ex.RequiredBytes} bytes, available {ex.AvailableBytes} bytes.";
        }
        finally
        {
            _cts = null;
        }
    }

    [RelayCommand]
    private void Cancel() => _cts?.Cancel();

    private void ReportProgress(OperationProgress progress)
    {
        LastProgress = progress;
        ProgressReported?.Invoke(this, progress);
    }

    private FileConflictResolution ResolveConflict(string destinationPath)
    {
        if (_applyToAllResolution is { } applyAll)
        {
            return applyAll;
        }

        var result = _conflictPrompt.PromptAsync(destinationPath).GetAwaiter().GetResult();
        if (result.ApplyToAll)
        {
            _applyToAllResolution = result.Resolution;
        }

        return result.Resolution;
    }

    private sealed class SynchronousProgress<T>(Action<T> callback) : IProgress<T>
    {
        public void Report(T value) => callback(value);
    }
}
