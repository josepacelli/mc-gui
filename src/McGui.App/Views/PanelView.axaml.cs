using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Input;
using McGui.App.ViewModels;

namespace McGui.App.Views;

public partial class PanelView : UserControl
{
    public PanelView()
    {
        InitializeComponent();
    }

    private void OnListSelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (DataContext is not PanelViewModel viewModel || sender is not ListBox listBox)
        {
            return;
        }

        if (listBox.SelectedIndex >= 0)
        {
            viewModel.MoveCursorTo(listBox.SelectedIndex);
        }
    }

    private async void OnListDoubleTapped(object? sender, TappedEventArgs e)
    {
        if (DataContext is not PanelViewModel viewModel || sender is not ListBox listBox)
        {
            return;
        }

        if (listBox.SelectedIndex >= 0)
        {
            viewModel.MoveCursorTo(listBox.SelectedIndex);
            await viewModel.ActivateCursorEntryCommand.ExecuteAsync(null);
        }
    }
}
