using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
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
