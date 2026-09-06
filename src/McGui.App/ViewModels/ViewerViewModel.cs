using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.App.ViewModels;

public sealed partial class ViewerViewModel : ObservableObject
{
    private readonly IViewerService _viewerService;
    private CancellationTokenSource? _loadCts;
    private List<int> _matchLineIndices = new();
    private int _currentMatchIndex = -1;

    public ViewerViewModel(IViewerService viewerService)
    {
        _viewerService = viewerService;
    }

    [ObservableProperty]
    private string _filePath = string.Empty;

    [ObservableProperty]
    private ViewerMode _mode = ViewerMode.Text;

    [ObservableProperty]
    private bool _wordWrap = true;

    [ObservableProperty]
    private string _content = string.Empty;

    [ObservableProperty]
    private string[] _lines = Array.Empty<string>();

    [ObservableProperty]
    private long _scrollOffset = 0;

    [ObservableProperty]
    private long _fileSize = 0;

    [ObservableProperty]
    private string _encoding = "UTF-8";

    [ObservableProperty]
    private bool _isBinary = false;

    [ObservableProperty]
    private string _title = "Viewer";

    [ObservableProperty]
    private bool _isLoading = false;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private string _searchQuery = string.Empty;

    private bool _isSearchVisible = false;

    public event Action? CloseRequested;

    public bool IsSearchVisible
    {
        get => _isSearchVisible;
        set
        {
            if (SetProperty(ref _isSearchVisible, value))
            {
                OnPropertyChanged(nameof(IsSearchVisible));
            }
        }
    }

    public bool HasSearchResults => _matchLineIndices.Count > 0;

    public string SearchMatchInfo
    {
        get
        {
            if (!HasSearchResults)
            {
                return "No matches";
            }
            return $"Match {_currentMatchIndex + 1} of {_matchLineIndices.Count}";
        }
    }

    partial void OnSearchQueryChanged(string value)
    {
        if (IsSearchVisible && value.Length > 0)
        {
            PerformSearch(value);
        }
        else
        {
            _matchLineIndices.Clear();
            _currentMatchIndex = -1;
            OnPropertyChanged(nameof(HasSearchResults));
            OnPropertyChanged(nameof(SearchMatchInfo));
        }
    }

    [RelayCommand]
    private async Task Load()
    {
        if (IsLoading || string.IsNullOrEmpty(FilePath))
        {
            return;
        }

        _loadCts?.Cancel();
        _loadCts = new CancellationTokenSource();

        Title = System.IO.Path.GetFileName(FilePath);
        IsLoading = true;
        StatusMessage = "Loading...";

        try
        {
            var content = await _viewerService.LoadFileAsync(FilePath, _loadCts.Token);
            ApplyContent(content);
            StatusMessage = "Ready";
        }
        catch (OperationCanceledException)
        {
            StatusMessage = "Cancelled";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Error: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    private void ApplyContent(ViewerContent viewerContent)
    {
        FileSize = viewerContent.FileSize;
        Encoding = viewerContent.Encoding;
        IsBinary = viewerContent.IsBinary;

        if (viewerContent.IsBinary || Mode == ViewerMode.Hex)
        {
            Mode = ViewerMode.Hex;
            BuildHexLines(viewerContent.Bytes ?? Array.Empty<byte>());
        }
        else
        {
            Mode = ViewerMode.Text;
            Content = viewerContent.Text;
            Lines = viewerContent.Text.Split('\n');
        }

        ScrollOffset = 0;
        _matchLineIndices.Clear();
        _currentMatchIndex = -1;
        OnPropertyChanged(nameof(Content));
        OnPropertyChanged(nameof(Lines));
        OnPropertyChanged(nameof(HasSearchResults));
        OnPropertyChanged(nameof(SearchMatchInfo));
    }

    private void BuildHexLines(byte[] bytes)
    {
        var lines = new List<string>();
        for (long i = 0; i < bytes.Length; i += 16)
        {
            var lineBytes = new byte[16];
            var count = Math.Min(16, bytes.Length - i);
            Array.Copy(bytes, i, lineBytes, 0, count);

            var hexBuilder = new StringBuilder();
            var asciiBuilder = new StringBuilder();

            for (int j = 0; j < 16; j++)
            {
                if (j < count)
                {
                    hexBuilder.Append(lineBytes[j].ToString("X2"));
                    hexBuilder.Append(' ');
                    var c = lineBytes[j];
                    asciiBuilder.Append(c >= 32 && c <= 126 ? (char)c : '.');
                }
                else
                {
                    hexBuilder.Append("   ");
                    asciiBuilder.Append(' ');
                }
            }

            var offset = i.ToString("X8");
            lines.Add($"{offset}  {hexBuilder} |{asciiBuilder}|");
        }

        Lines = lines.ToArray();
        Content = string.Join('\n', Lines);
    }

    [RelayCommand]
    private void ToggleWrap()
    {
        WordWrap = !WordWrap;
    }

    [RelayCommand]
    private void ToggleHex()
    {
        if (Mode == ViewerMode.Text)
        {
            if (IsBinary)
            {
                return;
            }
            var bytes = System.Text.Encoding.UTF8.GetBytes(Content);
            BuildHexLines(bytes);
            Mode = ViewerMode.Hex;
        }
        else
        {
            _ = ReloadAsync();
        }
    }

    [RelayCommand]
    private async Task ReloadAsync()
    {
        if (string.IsNullOrEmpty(FilePath))
        {
            return;
        }

        await Load();
    }

    [RelayCommand]
    private void Close()
    {
        _loadCts?.Cancel();
        CloseRequested?.Invoke();
    }

    [RelayCommand]
    private void Help()
    {
        // TODO: Show help dialog
        StatusMessage = "Help not implemented yet";
    }

    [RelayCommand]
    private void Search()
    {
        IsSearchVisible = true;
    }

    [RelayCommand]
    private void CloseSearch()
    {
        IsSearchVisible = false;
        SearchQuery = string.Empty;
    }

    [RelayCommand]
    private void NextMatch()
    {
        if (!HasSearchResults)
        {
            return;
        }

        _currentMatchIndex = (_currentMatchIndex + 1) % _matchLineIndices.Count;
        ScrollOffset = _matchLineIndices[_currentMatchIndex];
        OnPropertyChanged(nameof(SearchMatchInfo));
    }

    [RelayCommand]
    private void PreviousMatch()
    {
        if (!HasSearchResults)
        {
            return;
        }

        _currentMatchIndex = (_currentMatchIndex - 1 + _matchLineIndices.Count) % _matchLineIndices.Count;
        ScrollOffset = _matchLineIndices[_currentMatchIndex];
        OnPropertyChanged(nameof(SearchMatchInfo));
    }

    // Keyboard navigation
    public void ScrollUp() => ScrollOffset = Math.Max(0, ScrollOffset - 1);
    public void ScrollDown() => ScrollOffset = Math.Min(Lines.Length - 1, ScrollOffset + 1);
    public void ScrollPageUp() => ScrollOffset = Math.Max(0, ScrollOffset - 20);
    public void ScrollPageDown() => ScrollOffset = Math.Min(Lines.Length - 1, ScrollOffset + 20);
    public void ScrollToTop() => ScrollOffset = 0;
    public void ScrollToBottom() => ScrollOffset = Math.Max(0, Lines.Length - 1);

    private void PerformSearch(string query)
    {
        _matchLineIndices.Clear();
        _currentMatchIndex = -1;

        if (string.IsNullOrWhiteSpace(query))
        {
            OnPropertyChanged(nameof(HasSearchResults));
            OnPropertyChanged(nameof(SearchMatchInfo));
            return;
        }

        try
        {
            var regex = new Regex(Regex.Escape(query), RegexOptions.IgnoreCase);
            for (int i = 0; i < Lines.Length; i++)
            {
                if (regex.IsMatch(Lines[i]))
                {
                    _matchLineIndices.Add(i);
                }
            }

            if (_matchLineIndices.Count > 0)
            {
                _currentMatchIndex = 0;
                ScrollOffset = _matchLineIndices[0];
            }
        }
        catch
        {
            for (int i = 0; i < Lines.Length; i++)
            {
                if (Lines[i].Contains(query, StringComparison.OrdinalIgnoreCase))
                {
                    _matchLineIndices.Add(i);
                }
            }

            if (_matchLineIndices.Count > 0)
            {
                _currentMatchIndex = 0;
                ScrollOffset = _matchLineIndices[0];
            }
        }

        OnPropertyChanged(nameof(HasSearchResults));
        OnPropertyChanged(nameof(SearchMatchInfo));
    }
}