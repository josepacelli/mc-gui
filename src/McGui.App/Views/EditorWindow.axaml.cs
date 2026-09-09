using System;
using System.Threading;
using System.Collections.Specialized;
using System.IO;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using AvaloniaEdit;
using AvaloniaEdit.Document;
using AvaloniaEdit.TextMate;
using McGui.App.ViewModels;
using TextMateSharp.Grammars;

namespace McGui.App.Views;

public partial class EditorWindow : Window
{
    private readonly RegistryOptions _textMateRegistry;

    public EditorWindow()
    {
        InitializeComponent();
        _textMateRegistry = new RegistryOptions(ThemeName.LightPlus);
        DataContextChanged += OnDataContextChanged;
        KeyDown += OnKeyDown;
        Closing += OnWindowClosing;
    }

    private EditorWindowViewModel? ViewModel => DataContext as EditorWindowViewModel;

    private void OnDataContextChanged(object? sender, EventArgs e)
    {
        if (ViewModel is { } vm)
        {
            vm.Tabs.CollectionChanged += OnTabsChanged;
            vm.PropertyChanged += OnVmPropertyChanged;
            foreach (var tab in vm.Tabs)
            {
                AddTabItem(tab);
            }

            SyncSelection();
            UpdateStatus();
        }
    }

    private void OnTabsChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (e.Action == NotifyCollectionChangedAction.Add && e.NewItems is not null)
        {
            foreach (EditorTabViewModel tab in e.NewItems)
            {
                AddTabItem(tab);
            }
        }
        else if (e.Action == NotifyCollectionChangedAction.Remove && e.OldItems is not null)
        {
            foreach (EditorTabViewModel tab in e.OldItems)
            {
                var existing = EditorTabs.Items.OfType<TabItem>().FirstOrDefault(t => Equals(t.DataContext, tab));
                if (existing is not null)
                {
                    EditorTabs.Items.Remove(existing);
                }
            }
        }

        SyncSelection();
    }

    private void OnVmPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(EditorWindowViewModel.SelectedTab))
        {
            SyncSelection();
        }
    }

    private void SyncSelection()
    {
        if (ViewModel?.SelectedTab is { } selected)
        {
            foreach (var item in EditorTabs.Items.OfType<TabItem>())
            {
                if (Equals(item.DataContext, selected))
                {
                    EditorTabs.SelectedItem = item;
                    break;
                }
            }
        }
    }

    private void AddTabItem(EditorTabViewModel tab)
    {
        var editor = new TextEditor
        {
            FontFamily = new Avalonia.Media.FontFamily("Menlo, Consolas, monospace"),
            FontSize = 13,
            ShowLineNumbers = true,
            IsReadOnly = tab.IsReadOnly,
        };
        editor.Document = new TextDocument(tab.DocumentText);
        editor.Document.TextChanged += (_, _) =>
        {
            tab.DocumentText = editor.Document.Text;
            UpdateStatus();
        };
        editor.TextArea.Caret.PositionChanged += (_, _) => UpdateStatus();

        if (!tab.IsLarge)
        {
            InstallTextMateGrammar(editor, Path.GetExtension(tab.FilePath));
        }

        var header = new TextBlock();
        var tabItem = new TabItem { Header = header, Content = editor, DataContext = tab };
        tab.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(EditorTabViewModel.Title))
            {
                header.Text = tab.Title;
            }
        };
        header.Text = tab.Title;

        var closeButton = new Button { Content = "✕", Padding = new Avalonia.Thickness(4, 0) };
        closeButton.Click += async (_, _) => await ViewModel?.CloseTabCommand.ExecuteAsync(tab);
        var headerPanel = new StackPanel { Orientation = Avalonia.Layout.Orientation.Horizontal, Spacing = 4 };
        headerPanel.Children.Add(new TextBlock { Text = tab.Title, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center });
        headerPanel.Children.Add(closeButton);
        tabItem.Header = headerPanel;

        EditorTabs.Items.Add(tabItem);
        if (ReferenceEquals(ViewModel?.SelectedTab, tab))
        {
            EditorTabs.SelectedItem = tabItem;
        }

        editor.Loaded += (_, _) =>
        {
            editor.Focus();
            editor.CaretOffset = 0;
        };

        UpdateStatus();
    }

    private static void InstallTextMateGrammar(TextEditor editor, string extension)
    {
        try
        {
            var installation = editor.InstallTextMate(new RegistryOptions(ThemeName.LightPlus));
            var language = new RegistryOptions(ThemeName.LightPlus).GetLanguageByExtension(extension);
            if (language is not null)
            {
                var scope = new RegistryOptions(ThemeName.LightPlus).GetScopeByLanguageId(language.Id);
                if (!string.IsNullOrEmpty(scope))
                {
                    installation.SetGrammar(scope);
                }
            }
        }
        catch (Exception)
        {
            // Syntax highlighting is best-effort; plain text editor remains fully functional.
        }
    }

    private EditorTabViewModel? CurrentTab =>
        (EditorTabs.SelectedItem as TabItem)?.DataContext as EditorTabViewModel;

    private void UpdateStatus()
    {
        if (ViewModel?.SelectedTab is { } tab)
        {
            StatusEncoding.Text = $"Encoding: {tab.Encoding}";
            StatusReadOnly.Text = tab.IsReadOnly ? "Read-only" : string.Empty;
        }
        else
        {
            StatusEncoding.Text = string.Empty;
            StatusReadOnly.Text = string.Empty;
        }

        if (CurrentTab is { } current && EditorTabs.SelectedItem is TabItem { Content: TextEditor ed })
        {
            var pos = ed.TextArea.Caret;
            StatusPosition.Text = $"Ln {pos.Line}, Col {pos.Column}";
        }
        else
        {
            StatusPosition.Text = string.Empty;
        }
    }

    private TextEditor? CurrentEditor =>
        (EditorTabs.SelectedItem as TabItem)?.Content as TextEditor;

    private async void OnSaveClick(object? sender, RoutedEventArgs e)
    {
        if (ViewModel is { } vm)
        {
            await vm.SaveCommand.ExecuteAsync(null);
        }
    }

    private void OnFindClick(object? sender, RoutedEventArgs e)
    {
        SearchBar.IsVisible = true;
        SearchTextBox.Focus();
        SearchBar.Tag = "find";
    }

    private void OnReplaceClick(object? sender, RoutedEventArgs e)
    {
        SearchBar.IsVisible = true;
        SearchTextBox.Focus();
        SearchBar.Tag = "replace";
    }

    private void OnSearchNextClick(object? sender, RoutedEventArgs e) => DoSearch(next: true);
    private void OnSearchPrevClick(object? sender, RoutedEventArgs e) => DoSearch(next: false);

    private void OnReplaceClick2(object? sender, RoutedEventArgs e)
    {
        if (CurrentEditor is not { } editor)
        {
            return;
        }

        var caret = editor.TextArea.Caret.Offset;
        var replacement = ReplaceTextBox.Text ?? string.Empty;
        var options = CurrentSearchOptions();
        var pattern = SearchTextBox.Text ?? string.Empty;
        var (result, replaced) = EditorSearch.ReplaceNext(editor.Document.Text, pattern, replacement, options, caret);

        if (!replaced)
        {
            SearchStatus.Text = "No matches";
            return;
        }

        using (editor.Document.RunUpdate())
        {
            editor.Document.Text = result;
        }

        SearchStatus.Text = "1 replaced";
    }

    private void OnReplaceAllClick(object? sender, RoutedEventArgs e)
    {
        if (CurrentEditor is not { } editor)
        {
            return;
        }

        var options = CurrentSearchOptions();
        var replacement = ReplaceTextBox.Text ?? string.Empty;
        var (result, count) = EditorSearch.ReplaceAll(editor.Document.Text, SearchTextBox.Text ?? string.Empty, replacement, options);

        if (count > 0)
        {
            using (editor.Document.RunUpdate())
            {
                editor.Document.Text = result;
            }
        }

        SearchStatus.Text = count > 0 ? $"{count} replaced" : "No matches";
    }

    private SearchOptions CurrentSearchOptions() => new(
        Regex: RegexToggle.IsChecked == true,
        CaseSensitive: CaseToggle.IsChecked == true,
        WholeWord: WholeWordToggle.IsChecked == true);

    private void DoSearch(bool next)
    {
        if (CurrentEditor is not { } editor || ViewModel?.SelectedTab is not { } tab)
        {
            return;
        }

        var matches = EditorSearch.FindAll(editor.Document.Text, SearchTextBox.Text ?? string.Empty, CurrentSearchOptions());
        if (matches.Count == 0)
        {
            SearchStatus.Text = "No matches";
            return;
        }

        var caret = editor.TextArea.Caret.Offset;
        SearchMatch target;
        if (next)
        {
            target = matches.FirstOrDefault(m => m.Index > caret);
            if (target == default)
            {
                target = matches[0];
            }
        }
        else
        {
            var prior = matches.LastOrDefault(m => m.Index < caret);
            target = prior == default ? matches[^1] : prior;
        }

        editor.Select(target.Index, target.Length);
        editor.ScrollToLine(editor.Document.GetLineByOffset(target.Index).LineNumber);
        var idx = 1;
        for (var i = 0; i < matches.Count; i++)
        {
            if (matches[i] == target)
            {
                idx = i + 1;
                break;
            }
        }

        SearchStatus.Text = $"{idx} of {matches.Count}";
    }

    private void OnSearchKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            DoSearch(next: (e.KeyModifiers & KeyModifiers.Shift) == 0);
            e.Handled = true;
        }
        else if (e.Key == Key.Escape)
        {
            SearchBar.IsVisible = false;
            e.Handled = true;
        }
    }

    private async void OnQuitClick(object? sender, RoutedEventArgs e)
    {
        if (ViewModel is { } vm)
        {
            await vm.QuitCommand.ExecuteAsync(null);
        }
    }

    private async void OnWindowClosing(object? sender, global::Avalonia.Controls.WindowClosingEventArgs e)
    {
        if (ViewModel is { } vm)
        {
            await vm.QuitAsync();
            if (!vm.IsCompleted)
            {
                e.Cancel = true;
            }
        }
    }

    private async void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (ViewModel is not { } vm)
        {
            return;
        }

        var ctrl = (e.KeyModifiers & KeyModifiers.Control) != 0;
        var shift = (e.KeyModifiers & KeyModifiers.Shift) != 0;

        if (e.Key == Key.F2 || (ctrl && e.Key == Key.S))
        {
            var tab = vm.SelectedTab;
            if (tab is { } and { IsReadOnly: true })
            {
                // F2 on read-only tab → Save As
                var newPath = await vm.SaveAsPathProvider?.Invoke(tab.FilePath) ?? "";
                if (!string.IsNullOrEmpty(newPath))
                {
                    await tab.SaveAsAsync(newPath, CancellationToken.None);
                }
            }
            else
            {
                await vm.SaveCommand.ExecuteAsync(null);
            }
            e.Handled = true;
        }
        else if (e.Key == Key.F3)
        {
            DoSearch(next: !shift);
            e.Handled = true;
        }
        else if (e.Key == Key.F10 || e.Key == Key.Escape)
        {
            await vm.QuitCommand.ExecuteAsync(null);
            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.W)
        {
            await vm.CloseTabCommand.ExecuteAsync(null);
            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.Tab)
        {
            if (shift)
            {
                vm.PreviousTabCommand.Execute(null);
            }
            else
            {
                vm.NextTabCommand.Execute(null);
            }

            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.F)
        {
            OnFindClick(this, new RoutedEventArgs());
            e.Handled = true;
        }
        else if (ctrl && e.Key == Key.H)
        {
            OnReplaceClick(this, new RoutedEventArgs());
            e.Handled = true;
        }
    }

    private void OnHelpClick(object? sender, RoutedEventArgs e)
    {
        // No help viewer yet (matches F1 disabled elsewhere in the app).
    }
}