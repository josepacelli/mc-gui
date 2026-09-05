using Avalonia.Controls;
using McGui.App.ViewModels;

namespace McGui.App.Views;

public partial class ConflictDialog : Window
{
    public ConflictDialog()
    {
        InitializeComponent();
    }

    public ConflictDialogViewModel ViewModel => (ConflictDialogViewModel)DataContext!;
}
