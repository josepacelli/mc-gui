using System;
using Avalonia.Controls;
using Avalonia.Threading;
using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Views;

public partial class CopyMoveDialog : Window
{
    private ProgressDialogViewModel? _progressViewModel;
    private ProgressDialog? _progressWindow;

    public CopyMoveDialog()
    {
        InitializeComponent();
        DataContextChanged += OnDataContextChanged;
    }

    public CopyMoveDialogViewModel ViewModel => (CopyMoveDialogViewModel)DataContext!;

    private void OnDataContextChanged(object? sender, EventArgs e)
    {
        if (DataContext is not CopyMoveDialogViewModel viewModel)
        {
            return;
        }

        viewModel.ProgressReported += (_, progress) => Dispatcher.UIThread.Post(() => ApplyProgress(viewModel, progress));
        viewModel.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(CopyMoveDialogViewModel.IsCompleted) && viewModel.IsCompleted)
            {
                Dispatcher.UIThread.Post(() => _progressWindow?.Close());
            }
        };
    }

    private void ApplyProgress(CopyMoveDialogViewModel viewModel, OperationProgress progress)
    {
        if (_progressViewModel is null)
        {
            _progressViewModel = new ProgressDialogViewModel(() => viewModel.CancelCommand.Execute(null));
            _progressWindow = new ProgressDialog { DataContext = _progressViewModel };
            _progressWindow.Show(this);
        }

        _progressViewModel.Report(progress);
    }
}
