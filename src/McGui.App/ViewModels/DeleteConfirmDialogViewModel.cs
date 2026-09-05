using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.App.ViewModels;

public sealed partial class DeleteConfirmDialogViewModel : ObservableObject, ICompletable
{
    private readonly ITrashService _trashService;

    public DeleteConfirmDialogViewModel(ITrashService trashService, IReadOnlyList<FileEntry> entries)
    {
        _trashService = trashService;
        Entries = entries;
    }

    public IReadOnlyList<FileEntry> Entries { get; }

    public int Count => Entries.Count;

    public long TotalSizeBytes => Entries.Sum(e => e.SizeBytes);

    [ObservableProperty]
    private bool permanent;

    [ObservableProperty]
    private bool isCompleted;

    public OperationResult? Result { get; private set; }

    [RelayCommand]
    private Task Confirm() => ExecuteAsync(permanent: false);

    [RelayCommand]
    private Task ConfirmPermanent() => ExecuteAsync(permanent: true);

    private async Task ExecuteAsync(bool permanent)
    {
        Permanent = permanent;
        Result = await Task.Run(() => _trashService.Delete(Entries, permanent));
        IsCompleted = true;
    }
}
