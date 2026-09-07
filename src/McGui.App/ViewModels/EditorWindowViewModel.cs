using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Interfaces;

namespace McGui.App.ViewModels;

public sealed partial class EditorWindowViewModel : ObservableObject, ICompletable
{
    private readonly IEditorService _editorService;
    private readonly ISaveChangesPrompt _saveChangesPrompt;

    public EditorWindowViewModel(IEditorService editorService, ISaveChangesPrompt saveChangesPrompt)
    {
        _editorService = editorService;
        _saveChangesPrompt = saveChangesPrompt;
    }

    public ObservableCollection<EditorTabViewModel> Tabs { get; } = new();

    [ObservableProperty]
    private EditorTabViewModel? selectedTab;

    [ObservableProperty]
    private bool isCompleted;

    public bool HasDirtyTabs => Tabs.Any(t => t.IsDirty);

    public async Task OpenFileAsync(string filePath, System.Threading.CancellationToken ct)
    {
        var existing = Tabs.FirstOrDefault(t => string.Equals(t.FilePath, filePath, System.StringComparison.Ordinal));
        if (existing is not null)
        {
            SelectedTab = existing;
            return;
        }

        var doc = await _editorService.LoadAsync(filePath, ct);
        var tab = new EditorTabViewModel(
            _editorService,
            doc.FilePath,
            doc.Text,
            doc.Encoding,
            doc.IsReadOnly,
            doc.IsLarge);
        Tabs.Add(tab);
        SelectedTab = tab;
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (SelectedTab is null)
        {
            return;
        }

        if (SelectedTab.IsReadOnly)
        {
            return; // Save As handled at the view layer (T6); keep VM contract: read-only tabs are not saved in place.
        }

        await SelectedTab.SaveAsync(System.Threading.CancellationToken.None);
    }

    [RelayCommand]
    private async Task CloseTabAsync(EditorTabViewModel? tab)
    {
        tab ??= SelectedTab;
        if (tab is null)
        {
            return;
        }

        if (tab.IsDirty)
        {
            var choice = await _saveChangesPrompt.PromptAsync(tab.FileName);
            if (choice == SaveChangesResult.Cancel)
            {
                return;
            }

            if (choice == SaveChangesResult.Save && !tab.IsReadOnly)
            {
                await tab.SaveAsync(System.Threading.CancellationToken.None);
            }
        }

        Tabs.Remove(tab);
        if (SelectedTab == tab)
        {
            SelectedTab = Tabs.LastOrDefault();
        }
    }

    [RelayCommand]
    private void NextTab()
    {
        if (Tabs.Count == 0 || SelectedTab is null)
        {
            return;
        }

        var index = Tabs.IndexOf(SelectedTab);
        SelectedTab = Tabs[(index + 1) % Tabs.Count];
    }

    [RelayCommand]
    private void PreviousTab()
    {
        if (Tabs.Count == 0 || SelectedTab is null)
        {
            return;
        }

        var index = Tabs.IndexOf(SelectedTab);
        SelectedTab = Tabs[(index - 1 + Tabs.Count) % Tabs.Count];
    }

    [RelayCommand]
    private async Task QuitAsync()
    {
        if (!HasDirtyTabs)
        {
            IsCompleted = true;
            return;
        }

        // Prompt on each dirty tab, in order; Cancel aborts the whole quit.
        foreach (var tab in Tabs.Where(t => t.IsDirty).ToList())
        {
            var choice = await _saveChangesPrompt.PromptAsync(tab.FileName);
            if (choice == SaveChangesResult.Cancel)
            {
                return;
            }

            if (choice == SaveChangesResult.Save && !tab.IsReadOnly)
            {
                await tab.SaveAsync(System.Threading.CancellationToken.None);
            }
        }

        IsCompleted = true;
    }
}