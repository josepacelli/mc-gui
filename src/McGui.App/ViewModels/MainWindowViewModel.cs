using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Interfaces;

namespace McGui.App.ViewModels;

public sealed partial class MainWindowViewModel : ObservableObject
{
    [ObservableProperty]
    private PanelViewModel activePanel;

    public MainWindowViewModel(IFileSystemService fileSystemService, IPathHistoryStore pathHistoryStore)
    {
        LeftPanel = new PanelViewModel(fileSystemService, pathHistoryStore, PanelSide.Left);
        RightPanel = new PanelViewModel(fileSystemService, pathHistoryStore, PanelSide.Right);
        LeftPanel.IsActive = true;
        activePanel = LeftPanel;
    }

    public PanelViewModel LeftPanel { get; }

    public PanelViewModel RightPanel { get; }

    [RelayCommand]
    public void SwitchActivePanel()
    {
        var next = ReferenceEquals(ActivePanel, LeftPanel) ? RightPanel : LeftPanel;
        ActivePanel.IsActive = false;
        next.IsActive = true;
        ActivePanel = next;
    }
}
