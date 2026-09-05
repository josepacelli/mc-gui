using System;
using System.ComponentModel;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Platform;
using Avalonia.Styling;
using Avalonia.VisualTree;
using McGui.App.Input;
using McGui.App.ViewModels;
using McGui.App.Views;

namespace McGui.App;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        AddHandler(KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);
        DataContextChanged += OnDataContextChanged;
        Closing += OnClosing;
        Opened += OnOpened;
    }

    private void OnOpened(object? sender, EventArgs e)
    {
        var settings = this.GetPlatformSettings();
        if (settings is null)
        {
            return;
        }

        settings.ColorValuesChanged += OnColorValuesChanged;
        ApplySystemAccent(settings.GetColorValues());
    }

    private void OnColorValuesChanged(object? sender, PlatformColorValues values) => ApplySystemAccent(values);

    private void ApplySystemAccent(PlatformColorValues values)
    {
        Resources["PanelBorderActiveBrush"] = new SolidColorBrush(values.AccentColor1);
    }

    private void OnClosing(object? sender, WindowClosingEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        viewModel.LeftPanel.PersistCurrentDirectory();
        viewModel.RightPanel.PersistCurrentDirectory();
    }

    private void OnExitClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close();

    private void OnDataContextChanged(object? sender, EventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        viewModel.PropertyChanged += OnViewModelPropertyChanged;
        ApplyTheme(viewModel.CurrentTheme);

        viewModel.ConflictPrompt = new WindowConflictPrompt(this);
        viewModel.CopyMoveRequested += async (_, dialogViewModel) =>
            await ShowUntilCompletedAsync(new CopyMoveDialog(), dialogViewModel, RefreshBothPanelsAsync);
        viewModel.DeleteRequested += async (_, dialogViewModel) =>
            await ShowUntilCompletedAsync(new DeleteConfirmDialog(), dialogViewModel, RefreshBothPanelsAsync);
        viewModel.MkdirRequested += async (_, dialogViewModel) =>
            await ShowUntilCompletedAsync(new MkdirDialog(), dialogViewModel, RefreshActivePanelAsync);
    }

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(MainWindowViewModel.CurrentTheme) || DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        ApplyTheme(viewModel.CurrentTheme);
    }

    private static void ApplyTheme(ThemePreference preference)
    {
        Application.Current!.RequestedThemeVariant = preference switch
        {
            ThemePreference.Light => ThemeVariant.Light,
            ThemePreference.Dark => ThemeVariant.Dark,
            _ => ThemeVariant.Default,
        };
    }

    private async Task ShowUntilCompletedAsync<TViewModel>(
        Window dialog,
        TViewModel dialogViewModel,
        Func<Task> refreshAfter)
        where TViewModel : class, ICompletable
    {
        dialog.DataContext = dialogViewModel;
        using var _ = DialogCompletion.CloseOnCompleted(dialog, dialogViewModel);

        await dialog.ShowDialog(this);
        await refreshAfter();
    }

    private async Task RefreshBothPanelsAsync()
    {
        if (DataContext is MainWindowViewModel viewModel)
        {
            await viewModel.LeftPanel.NavigateToAsync(viewModel.LeftPanel.CurrentDirectory);
            await viewModel.RightPanel.NavigateToAsync(viewModel.RightPanel.CurrentDirectory);
        }
    }

    private async Task RefreshActivePanelAsync()
    {
        if (DataContext is MainWindowViewModel viewModel)
        {
            await viewModel.ActivePanel.NavigateToAsync(viewModel.ActivePanel.CurrentDirectory);
        }
    }

    private async void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var activePanel = viewModel.ActivePanel;

        switch (e.Key)
        {
            case Key.Up:
                activePanel.MoveCursorUpCommand.Execute(null);
                e.Handled = true;
                return;
            case Key.Down:
                activePanel.MoveCursorDownCommand.Execute(null);
                e.Handled = true;
                return;
            case Key.Enter:
                await activePanel.ActivateCursorEntryCommand.ExecuteAsync(null);
                e.Handled = true;
                return;
        }

        var gesture = new KeyGesture(e.Key, e.KeyModifiers);
        if (!KeyGestureMap.Gestures.TryGetValue(gesture, out var action))
        {
            return;
        }

        if (KeyGestureMap.DisabledActions.Contains(action))
        {
            e.Handled = true;
            return;
        }

        switch (action)
        {
            case GestureAction.SwitchActivePanel:
                viewModel.SwitchActivePanelCommand.Execute(null);
                break;
            case GestureAction.NavigateToParent:
                await activePanel.NavigateToParentCommand.ExecuteAsync(null);
                break;
            case GestureAction.ToggleMark:
                activePanel.ToggleMarkCommand.Execute(activePanel.CursorIndex);
                break;
            case GestureAction.InvertMarks:
                activePanel.InvertMarksCommand.Execute(null);
                break;
            case GestureAction.MarkByPattern:
                await PromptAndApplyPatternAsync(activePanel, unmark: false);
                break;
            case GestureAction.UnmarkByPattern:
                await PromptAndApplyPatternAsync(activePanel, unmark: true);
                break;
            case GestureAction.Copy:
                viewModel.RequestCopyCommand.Execute(null);
                break;
            case GestureAction.Move:
                viewModel.RequestMoveCommand.Execute(null);
                break;
            case GestureAction.Delete:
                viewModel.RequestDeleteCommand.Execute(null);
                break;
            case GestureAction.MakeDirectory:
                viewModel.RequestMkdirCommand.Execute(null);
                break;
            case GestureAction.RefreshPanel:
                await activePanel.RefreshCommand.ExecuteAsync(null);
                break;
            case GestureAction.CycleTheme:
                viewModel.CycleThemeCommand.Execute(null);
                break;
            default:
                return;
        }

        e.Handled = true;
    }

    private async Task PromptAndApplyPatternAsync(PanelViewModel panel, bool unmark)
    {
        var title = unmark ? "Unmark by pattern" : "Mark by pattern";
        var pattern = await TextPromptDialog.ShowAsync(this, title, "Glob pattern:");
        if (string.IsNullOrEmpty(pattern))
        {
            return;
        }

        if (unmark)
        {
            panel.UnmarkByPatternCommand.Execute(pattern);
        }
        else
        {
            panel.MarkByPatternCommand.Execute(pattern);
        }
    }
}
