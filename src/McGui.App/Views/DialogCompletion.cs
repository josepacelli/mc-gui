using System;
using System.ComponentModel;
using Avalonia.Controls;
using McGui.App.ViewModels;

namespace McGui.App.Views;

public static class DialogCompletion
{
    public static IDisposable CloseOnCompleted(Window dialog, ICompletable viewModel)
    {
        void Handler(object? sender, PropertyChangedEventArgs args)
        {
            if (args.PropertyName == nameof(ICompletable.IsCompleted) && viewModel.IsCompleted)
            {
                dialog.Close();
            }
        }

        viewModel.PropertyChanged += Handler;
        return new ActionDisposable(() => viewModel.PropertyChanged -= Handler);
    }

    private sealed class ActionDisposable(Action dispose) : IDisposable
    {
        public void Dispose() => dispose();
    }
}
