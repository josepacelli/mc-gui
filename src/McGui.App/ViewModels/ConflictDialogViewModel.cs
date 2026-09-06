using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Models;

namespace McGui.App.ViewModels;

public sealed partial class ConflictDialogViewModel : ObservableObject
{
    private readonly TaskCompletionSource<ConflictPromptResult> _completion = new();

    public ConflictDialogViewModel(string destinationPath)
    {
        DestinationPath = destinationPath;
    }

    public string DestinationPath { get; }

    [ObservableProperty]
    private bool applyToAll;

    public Task<ConflictPromptResult> ResultTask => _completion.Task;

    [RelayCommand]
    private void Overwrite() => Complete(FileConflictResolution.Overwrite);

    [RelayCommand]
    private void Skip() => Complete(FileConflictResolution.Skip);

    [RelayCommand]
    private void Rename() => Complete(FileConflictResolution.Rename);

    [RelayCommand]
    private void Update() => Complete(FileConflictResolution.Update);

    [RelayCommand]
    private void Abort() => Complete(FileConflictResolution.Abort);

    private void Complete(FileConflictResolution resolution) =>
        _completion.TrySetResult(new ConflictPromptResult(resolution, ApplyToAll));
}
