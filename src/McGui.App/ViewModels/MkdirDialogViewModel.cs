using System;
using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Interfaces;

namespace McGui.App.ViewModels;

public sealed partial class MkdirDialogViewModel : ObservableObject, ICompletable
{
    private readonly IFileSystemService _fileSystemService;
    private readonly string _parentDirectory;

    public MkdirDialogViewModel(IFileSystemService fileSystemService, string parentDirectory)
    {
        _fileSystemService = fileSystemService;
        _parentDirectory = parentDirectory;
    }

    public string ParentDirectory => _parentDirectory;

    [ObservableProperty]
    private string name = string.Empty;

    [ObservableProperty]
    private string? errorMessage;

    [ObservableProperty]
    private bool isCompleted;

    public bool HasError => !string.IsNullOrEmpty(ErrorMessage);

    partial void OnErrorMessageChanged(string? value) => OnPropertyChanged(nameof(HasError));

    [RelayCommand]
    private void Confirm()
    {
        ErrorMessage = null;
        try
        {
            _fileSystemService.CreateDirectory(_parentDirectory, Name);
            IsCompleted = true;
        }
        catch (IOException ex)
        {
            ErrorMessage = ex.Message;
        }
        catch (ArgumentException ex)
        {
            ErrorMessage = ex.Message;
        }
    }
}
