using Avalonia.Controls;
using McGui.App.ViewModels;

namespace McGui.App.Views;

public partial class CopyMoveDialog : Window
{
    public CopyMoveDialog()
    {
        InitializeComponent();
    }

    public CopyMoveDialogViewModel ViewModel => (CopyMoveDialogViewModel)DataContext!;
}
