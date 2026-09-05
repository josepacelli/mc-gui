using System;
using Avalonia.Controls;
using Avalonia.Threading;
using McGui.App.ViewModels;

namespace McGui.App.Views;

public partial class CopyMoveDialog : Window
{
    public CopyMoveDialog()
    {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    public CopyMoveDialogViewModel ViewModel => (CopyMoveDialogViewModel)DataContext!;

    private void OnDataContextChanged(object? sender, EventArgs e)
    {
        if (DataContext is CopyMoveDialogViewModel viewModel)
        {
            viewModel.ProgressReported += (_, _) =>
                Dispatcher.UIThread.Post(() => viewModel.RaiseProgressChangedOnUiThread());
        }
    }
}
