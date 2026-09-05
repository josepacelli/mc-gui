using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Threading;
using McGui.App.ViewModels;

namespace McGui.App.Views;

public sealed class WindowConflictPrompt(Window owner) : IConflictPrompt
{
    public Task<ConflictPromptResult> PromptAsync(string destinationPath) =>
        Dispatcher.UIThread.InvokeAsync(async () =>
        {
            var viewModel = new ConflictDialogViewModel(destinationPath);
            var dialog = new ConflictDialog { DataContext = viewModel };
            var closed = dialog.ShowDialog(owner);
            var result = await viewModel.ResultTask;
            dialog.Close();
            await closed;
            return result;
        });
}
