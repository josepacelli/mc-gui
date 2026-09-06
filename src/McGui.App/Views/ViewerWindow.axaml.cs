using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using McGui.App.ViewModels;

namespace McGui.App.Views;

public partial class ViewerWindow : Window
{
    public ViewerWindow()
    {
        InitializeComponent();
        
        // Handle keyboard shortcuts at window level
        KeyDown += OnKeyDown;
        Loaded += OnLoaded;
    }

    private void OnLoaded(object? sender, RoutedEventArgs e)
    {
        // Focus the window for keyboard handling
        Focus();
    }

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not ViewerViewModel vm)
        {
            return;
        }

        switch (e.Key)
        {
            case Key.F2:
                vm.ToggleWrapCommand.Execute(null);
                e.Handled = true;
                break;
            case Key.F3:
                if (vm.HasSearchResults)
                {
                    if ((e.KeyModifiers & KeyModifiers.Shift) != 0)
                    {
                        vm.PreviousMatchCommand.Execute(null);
                    }
                    else
                    {
                        vm.NextMatchCommand.Execute(null);
                    }
                }
                e.Handled = true;
                break;
            case Key.F4:
                vm.ToggleHexCommand.Execute(null);
                e.Handled = true;
                break;
            case Key.F5:
                vm.ReloadCommand.Execute(null);
                e.Handled = true;
                break;
            case Key.F7:
            case Key.F when (e.KeyModifiers & KeyModifiers.Control) != 0:
                vm.SearchCommand.Execute(null);
                e.Handled = true;
                break;
            case Key.F10:
            case Key.Escape:
                vm.CloseCommand.Execute(null);
                e.Handled = true;
                break;
            case Key.Up:
                if (!vm.IsSearchVisible || !SearchTextBox.IsFocused)
                {
                    vm.ScrollUp();
                    e.Handled = true;
                }
                break;
            case Key.Down:
                if (!vm.IsSearchVisible || !SearchTextBox.IsFocused)
                {
                    vm.ScrollDown();
                    e.Handled = true;
                }
                break;
            case Key.PageUp:
                vm.ScrollPageUp();
                e.Handled = true;
                break;
            case Key.PageDown:
                vm.ScrollPageDown();
                e.Handled = true;
                break;
            case Key.Home:
                if ((e.KeyModifiers & KeyModifiers.Control) != 0)
                {
                    vm.ScrollToTop();
                }
                e.Handled = true;
                break;
            case Key.End:
                if ((e.KeyModifiers & KeyModifiers.Control) != 0)
                {
                    vm.ScrollToBottom();
                }
                e.Handled = true;
                break;
        }
    }

    private void OnSearchKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not ViewerViewModel vm)
        {
            return;
        }

        if (e.Key == Key.Enter)
        {
            if ((e.KeyModifiers & KeyModifiers.Shift) != 0)
            {
                vm.PreviousMatchCommand.Execute(null);
            }
            else
            {
                vm.NextMatchCommand.Execute(null);
            }
            e.Handled = true;
        }
        else if (e.Key == Key.Escape)
        {
            vm.CloseSearchCommand.Execute(null);
            e.Handled = true;
        }
    }
}