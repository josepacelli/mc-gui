using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace McGui.App.ViewModels;

public sealed partial class SaveChangesDialogViewModel(string fileName) : ObservableObject
{
    private readonly TaskCompletionSource<SaveChangesResult> _completion = new();

    public string FileName { get; } = fileName;

    public string Message => $"Save changes to \"{FileName}\" before closing?";

    public Task<SaveChangesResult> ResultTask => _completion.Task;

    [RelayCommand]
    private void Save() => Complete(SaveChangesResult.Save);

    [RelayCommand]
    private void Discard() => Complete(SaveChangesResult.Discard);

    [RelayCommand]
    private void Cancel() => Complete(SaveChangesResult.Cancel);

    private void Complete(SaveChangesResult result) => _completion.TrySetResult(result);
}