using Avalonia.Controls;
using Avalonia.Interactivity;

namespace McGui.App.Views;

public partial class DeleteConfirmDialog : Window
{
    public DeleteConfirmDialog()
    {
        InitializeComponent();
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();
}
