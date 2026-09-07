using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Threading;
using McGui.App.ViewModels;

namespace McGui.App.Views;

public sealed class WindowSaveChangesPrompt(Window owner) : ISaveChangesPrompt
{
    public Task<SaveChangesResult> PromptAsync(string fileName) =>
        Dispatcher.UIThread.InvokeAsync(async () =>
        {
            var viewModel = new SaveChangesDialogViewModel(fileName);
            var dialog = new SaveChangesDialog { DataContext = viewModel };
            var closed = dialog.ShowDialog(owner);
            var result = await viewModel.ResultTask;
            dialog.Close();
            await closed;
            return result;
        });
}