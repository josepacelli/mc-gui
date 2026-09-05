using System;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Models;

namespace McGui.App.ViewModels;

public sealed partial class ProgressDialogViewModel(Action requestCancel) : ObservableObject
{
    [ObservableProperty]
    private string currentFileName = string.Empty;

    [ObservableProperty]
    private int filesDone;

    [ObservableProperty]
    private int filesTotal;

    [ObservableProperty]
    private long bytesDone;

    [ObservableProperty]
    private long bytesTotal;

    [ObservableProperty]
    private bool isCancelled;

    public double PercentComplete
    {
        get
        {
            if (BytesTotal > 0)
            {
                return (double)BytesDone / BytesTotal * 100;
            }

            return FilesTotal > 0 ? (double)FilesDone / FilesTotal * 100 : 0;
        }
    }

    [RelayCommand]
    private void Cancel()
    {
        IsCancelled = true;
        requestCancel();
    }

    public void Report(OperationProgress progress)
    {
        CurrentFileName = progress.CurrentFileName;
        FilesDone = progress.FilesDone;
        FilesTotal = progress.FilesTotal;
        BytesDone = progress.BytesDone;
        BytesTotal = progress.BytesTotal;
        OnPropertyChanged(nameof(PercentComplete));
    }
}
