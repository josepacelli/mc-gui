using McGui.App.Tests.Fakes;
using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Tests.ViewModels;

public class MainWindowViewModelTests
{
    private static (FakeFileSystemService FileSystem, FakeTrashService Trash, FakePathHistoryStore History, FakeViewerService Viewer, FakeEditorService Editor) BuildDependencies()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left", new FileEntry("a.txt", "/left/a.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        fs.AddDirectory("/right", new FileEntry("b.txt", "/right/b.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        return (fs, new FakeTrashService(), history, new FakeViewerService(), new FakeEditorService());
    }

    [Fact]
    public void Constructor_LeftPanelIsActiveByDefault()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();

        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);

        Assert.Same(vm.LeftPanel, vm.ActivePanel);
        Assert.True(vm.LeftPanel.IsActive);
        Assert.False(vm.RightPanel.IsActive);
    }

    [Fact]
    public void SwitchActivePanel_TogglesFromLeftToRight()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);

        vm.SwitchActivePanel();

        Assert.Same(vm.RightPanel, vm.ActivePanel);
        Assert.True(vm.RightPanel.IsActive);
        Assert.False(vm.LeftPanel.IsActive);
    }

    [Fact]
    public void SwitchActivePanel_CalledTwice_ReturnsToLeftPanel()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);

        vm.SwitchActivePanel();
        vm.SwitchActivePanel();

        Assert.Same(vm.LeftPanel, vm.ActivePanel);
        Assert.True(vm.LeftPanel.IsActive);
        Assert.False(vm.RightPanel.IsActive);
    }

    [Fact]
    public void RequestCopy_WithCursorEntry_PrefillsOppositePanelAsDestination()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);
        CopyMoveDialogViewModel? requested = null;
        vm.CopyMoveRequested += (_, dialog) => requested = dialog;

        vm.RequestCopy();

        Assert.NotNull(requested);
        Assert.Equal(OperationMode.Copy, requested!.Mode);
        Assert.Equal("/right", requested.DestinationDirectory);
        Assert.Single(requested.Sources);
        Assert.Equal("/left/a.txt", requested.Sources[0].FullPath);
    }

    [Fact]
    public void RequestMove_SingleMarkedEntry_PrefillsSourceOwnDirectoryToEnableRename()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);
        vm.ActivePanel.ToggleMark(0);
        CopyMoveDialogViewModel? requested = null;
        vm.CopyMoveRequested += (_, dialog) => requested = dialog;

        vm.RequestMove();

        Assert.NotNull(requested);
        Assert.Equal(OperationMode.Move, requested!.Mode);
        Assert.Equal("/left", requested.DestinationDirectory);
        Assert.True(requested.CanRename);
    }

    [Fact]
    public void RequestMove_MultipleMarkedEntries_PrefillsOppositePanelAsDestination()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory(
            "/left",
            new FileEntry("a.txt", "/left/a.txt", false, 1, DateTimeOffset.UnixEpoch, false, false),
            new FileEntry("b.txt", "/left/b.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        fs.AddDirectory("/right", new FileEntry("c.txt", "/right/c.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history, new FakeViewerService(), new FakeEditorService());
        vm.ActivePanel.ToggleMark(1);
        vm.ActivePanel.ToggleMark(2);
        CopyMoveDialogViewModel? requested = null;
        vm.CopyMoveRequested += (_, dialog) => requested = dialog;

        vm.RequestMove();

        Assert.NotNull(requested);
        Assert.Equal(2, requested!.Sources.Count);
        Assert.Equal("/right", requested.DestinationDirectory);
        Assert.False(requested.CanRename);
    }

    [Fact]
    public void RequestCopy_NoMarkedEntriesAndNoCursorEntry_DoesNotRaiseCopyMoveRequested()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left");
        fs.AddDirectory("/right");
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history, new FakeViewerService(), new FakeEditorService());
        var raised = false;
        vm.CopyMoveRequested += (_, _) => raised = true;

        vm.RequestCopy();

        Assert.False(raised);
    }

    [Fact]
    public void RequestCopy_CursorOnDotDot_DoesNotRaiseCopyMoveRequested()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left", new FileEntry("a.txt", "/left/a.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        fs.AddDirectory("/right", new FileEntry("b.txt", "/right/b.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history, new FakeViewerService(), new FakeEditorService());
        vm.ActivePanel.MoveCursorTo(0);
        var raised = false;
        vm.CopyMoveRequested += (_, _) => raised = true;

        vm.RequestCopy();

        Assert.False(raised);
    }

    [Fact]
    public void RequestCopy_OneMarkedEntry_ExcludesDotDotFromSources()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left", new FileEntry("a.txt", "/left/a.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        fs.AddDirectory("/right", new FileEntry("b.txt", "/right/b.txt", false, 1, DateTimeOffset.UnixEpoch, false, false));
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history, new FakeViewerService(), new FakeEditorService());
        vm.ActivePanel.ToggleMark(1);
        CopyMoveDialogViewModel? requested = null;
        vm.CopyMoveRequested += (_, dialog) => requested = dialog;

        vm.RequestCopy();

        Assert.NotNull(requested);
        Assert.Single(requested!.Sources);
        Assert.Equal("/left/a.txt", requested.Sources[0].FullPath);
    }

    [Fact]
    public void RequestMove_NoMarkedEntriesAndNoCursorEntry_DoesNotRaiseCopyMoveRequested()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left");
        fs.AddDirectory("/right");
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history, new FakeViewerService(), new FakeEditorService());
        var raised = false;
        vm.CopyMoveRequested += (_, _) => raised = true;

        vm.RequestMove();

        Assert.False(raised);
    }

    [Fact]
    public void RequestDelete_WithCursorEntry_RaisesDeleteRequestedWithSelectedEntries()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);
        DeleteConfirmDialogViewModel? requested = null;
        vm.DeleteRequested += (_, dialog) => requested = dialog;

        vm.RequestDelete();

        Assert.NotNull(requested);
        Assert.Single(requested!.Entries);
        Assert.Equal("/left/a.txt", requested.Entries[0].FullPath);
    }

    [Fact]
    public void RequestDelete_NoMarkedEntriesAndNoCursorEntry_DoesNotRaiseDeleteRequested()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left");
        fs.AddDirectory("/right");
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history, new FakeViewerService(), new FakeEditorService());
        var raised = false;
        vm.DeleteRequested += (_, _) => raised = true;

        vm.RequestDelete();

        Assert.False(raised);
    }

    [Fact]
    public void RequestMkdir_RaisesMkdirRequestedForActivePanelDirectory()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);
        MkdirDialogViewModel? requested = null;
        vm.MkdirRequested += (_, dialog) => requested = dialog;

        vm.RequestMkdir();

        Assert.NotNull(requested);
        Assert.Equal("/left", requested!.ParentDirectory);
    }

    [Fact]
    public void Constructor_CurrentThemeDefaultsToSystem()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);

        Assert.Equal(ThemePreference.System, vm.CurrentTheme);
        Assert.True(vm.IsSystemThemeChecked);
        Assert.False(vm.IsLightThemeChecked);
        Assert.False(vm.IsDarkThemeChecked);
    }

    [Fact]
    public void SetTheme_ForEachPreference_UpdatesCurrentThemeAndCheckState()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);

        vm.SetTheme(ThemePreference.Light);

        Assert.Equal(ThemePreference.Light, vm.CurrentTheme);
        Assert.True(vm.IsLightThemeChecked);
        Assert.False(vm.IsSystemThemeChecked);
        Assert.False(vm.IsDarkThemeChecked);

        vm.SetTheme(ThemePreference.Dark);

        Assert.Equal(ThemePreference.Dark, vm.CurrentTheme);
        Assert.True(vm.IsDarkThemeChecked);
        Assert.False(vm.IsLightThemeChecked);

        vm.SetTheme(ThemePreference.System);

        Assert.Equal(ThemePreference.System, vm.CurrentTheme);
        Assert.True(vm.IsSystemThemeChecked);
        Assert.False(vm.IsDarkThemeChecked);
    }

    [Fact]
    public void CycleTheme_FromSystem_MovesToLight()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);

        vm.CycleTheme();

        Assert.Equal(ThemePreference.Light, vm.CurrentTheme);
    }

    [Fact]
    public void CycleTheme_FromLight_MovesToDark()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);
        vm.SetTheme(ThemePreference.Light);

        vm.CycleTheme();

        Assert.Equal(ThemePreference.Dark, vm.CurrentTheme);
    }

    [Fact]
    public void CycleTheme_FromDark_ReturnsToSystem()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);
        vm.SetTheme(ThemePreference.Dark);

        vm.CycleTheme();

        Assert.Equal(ThemePreference.System, vm.CurrentTheme);
        Assert.True(vm.IsSystemThemeChecked);
    }

    [Fact]
    public void CycleTheme_ThreeTimes_ReturnsToSystem()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);

        vm.CycleTheme();
        vm.CycleTheme();
        vm.CycleTheme();

        Assert.Equal(ThemePreference.System, vm.CurrentTheme);
    }

    [Fact]
    public void SetTheme_RaisesPropertyChangedForCurrentThemeAndCheckStates()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);
        var changed = new List<string?>();
        vm.PropertyChanged += (_, e) => changed.Add(e.PropertyName);

        vm.SetTheme(ThemePreference.Dark);

        Assert.Contains(nameof(vm.CurrentTheme), changed);
        Assert.Contains(nameof(vm.IsDarkThemeChecked), changed);
        Assert.Contains(nameof(vm.IsLightThemeChecked), changed);
        Assert.Contains(nameof(vm.IsSystemThemeChecked), changed);
    }

    [Fact]
    public void IsMacOS_MatchesOperatingSystemCheck()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);

        Assert.Equal(OperatingSystem.IsMacOS(), vm.IsMacOS);
    }

    [Fact]
    public void RequestEdit_WithCursorFile_RaisesEditRequestedWithPath()
    {
        var (fs, trash, history, viewer, editor) = BuildDependencies();
        var vm = new MainWindowViewModel(fs, trash, history, viewer, editor);
        EditorWindowViewModel? requested = null;
        vm.EditRequested += (_, editorVm) => requested = editorVm;

        vm.RequestEdit();

        Assert.NotNull(requested);
        Assert.NotNull(requested!.InitialOpenPaths);
        Assert.Equal("/left/a.txt", Assert.Single(requested.InitialOpenPaths));
    }

    [Fact]
    public void RequestEdit_CursorOnDirectory_DoesNotRaiseEditRequested()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left", new FileEntry("adir", "/left/adir", true, 0, DateTimeOffset.UnixEpoch, false, false));
        fs.AddDirectory("/right");
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history, new FakeViewerService(), new FakeEditorService());
        vm.ActivePanel.MoveCursorTo(0);
        var raised = false;
        vm.EditRequested += (_, _) => raised = true;

        vm.RequestEdit();

        Assert.False(raised);
    }

    [Fact]
    public void RequestEdit_MarkedFiles_OpensAllNonDirectories()
    {
        var fs = new FakeFileSystemService();
        fs.AddDirectory("/left",
            new FileEntry("a.txt", "/left/a.txt", false, 1, DateTimeOffset.UnixEpoch, false, false),
            new FileEntry("b.txt", "/left/b.txt", false, 1, DateTimeOffset.UnixEpoch, false, false),
            new FileEntry("adir", "/left/adir", true, 0, DateTimeOffset.UnixEpoch, false, false));
        fs.AddDirectory("/right");
        var history = new FakePathHistoryStore { History = new PanelPathHistory("/left", "/right") };
        var vm = new MainWindowViewModel(fs, new FakeTrashService(), history, new FakeViewerService(), new FakeEditorService());
        vm.ActivePanel.ToggleMark(1);
        vm.ActivePanel.ToggleMark(2);
        EditorWindowViewModel? requested = null;
        vm.EditRequested += (_, editorVm) => requested = editorVm;

        vm.RequestEdit();

        Assert.NotNull(requested);
        Assert.Equal(2, requested!.InitialOpenPaths!.Count);
        Assert.Contains("/left/a.txt", requested.InitialOpenPaths);
        Assert.Contains("/left/b.txt", requested.InitialOpenPaths);
    }
}
