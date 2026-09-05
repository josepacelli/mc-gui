using Avalonia.Controls;
using Avalonia.Interactivity;

namespace McGui.App.Views;

public partial class MkdirDialog : Window
{
    public MkdirDialog()
    {
        InitializeComponent();
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();
}
