using System.ComponentModel;

namespace McGui.App.ViewModels;

public interface ICompletable : INotifyPropertyChanged
{
    bool IsCompleted { get; }
}
