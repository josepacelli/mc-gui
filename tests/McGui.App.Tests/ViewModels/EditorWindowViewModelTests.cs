using System.Runtime.Versioning;
using McGui.App.ViewModels;
using McGui.Infrastructure.macOS;

namespace McGui.App.Tests.ViewModels;

[SupportedOSPlatform("macos")]
public class EditorWindowViewModelTests : IDisposable
{
    private readonly DirectoryInfo _root = Directory.CreateTempSubdirectory("mcgui-editor-vm-");
    private readonly MacEditorService _editorService = new();
    private readonly Queue<SaveChangesResult> _promptAnswers = new();
    private readonly EditorWindowViewModel _vm;

    public EditorWindowViewModelTests()
    {
        _vm = new EditorWindowViewModel(_editorService, new QueueSaveChangesPrompt(_promptAnswers));
    }

    public void Dispose()
    {
        try
        {
            _root.Delete(recursive: true);
        }
        catch (IOException)
        {
        }
    }

    private sealed class QueueSaveChangesPrompt(Queue<SaveChangesResult> answers) : ISaveChangesPrompt
    {
        public Task<SaveChangesResult> PromptAsync(string fileName) =>
            Task.FromResult(answers.Count > 0 ? answers.Dequeue() : SaveChangesResult.Cancel);
    }

    private string NewFile(string name, string content)
    {
        var path = Path.Combine(_root.FullName, name);
        File.WriteAllText(path, content);
        return path;
    }

    [Fact]
    public async Task OpenFile_AddsTabAndSelectsIt()
    {
        var path = NewFile("a.txt", "alpha");

        await _vm.OpenFileAsync(path, CancellationToken.None);

        Assert.Single(_vm.Tabs);
        Assert.Same(_vm.Tabs[0], _vm.SelectedTab);
        Assert.Equal("alpha", _vm.Tabs[0].DocumentText);
    }

    [Fact]
    public async Task OpenFile_SecondFile_AddsSecondTab()
    {
        var pathA = NewFile("a.txt", "alpha");
        var pathB = NewFile("b.txt", "beta");

        await _vm.OpenFileAsync(pathA, CancellationToken.None);
        await _vm.OpenFileAsync(pathB, CancellationToken.None);

        Assert.Equal(2, _vm.Tabs.Count);
        Assert.Same(_vm.Tabs[1], _vm.SelectedTab);
    }

    [Fact]
    public async Task OpenFile_SameFileTwice_FocusesExistingTabInsteadOfDuplicating()
    {
        var path = NewFile("a.txt", "alpha");

        await _vm.OpenFileAsync(path, CancellationToken.None);
        var first = _vm.Tabs[0];
        await _vm.OpenFileAsync(path, CancellationToken.None);

        Assert.Single(_vm.Tabs);
        Assert.Same(first, _vm.SelectedTab);
    }

    [Fact]
    public async Task SaveCommand_WritesToDiskAndClearsDirty()
    {
        var path = NewFile("s.txt", "original");
        await _vm.OpenFileAsync(path, CancellationToken.None);
        _vm.Tabs[0].DocumentText = "edited";

        await _vm.SaveCommand.ExecuteAsync(null);

        Assert.False(_vm.Tabs[0].IsDirty);
        Assert.Equal("edited", File.ReadAllText(path));
    }

    [Fact]
    public async Task CloseTab_DirtyDiscard_RemovesTabWithoutSaving()
    {
        var path = NewFile("d.txt", "original");
        await _vm.OpenFileAsync(path, CancellationToken.None);
        _vm.Tabs[0].DocumentText = "changed";
        _promptAnswers.Enqueue(SaveChangesResult.Discard);

        await _vm.CloseTabCommand.ExecuteAsync(_vm.Tabs[0]);

        Assert.Empty(_vm.Tabs);
        Assert.Equal("original", File.ReadAllText(path));
    }

    [Fact]
    public async Task CloseTab_DirtySave_SavesThenRemoves()
    {
        var path = NewFile("c.txt", "original");
        await _vm.OpenFileAsync(path, CancellationToken.None);
        _vm.Tabs[0].DocumentText = "persisted";
        _promptAnswers.Enqueue(SaveChangesResult.Save);

        await _vm.CloseTabCommand.ExecuteAsync(_vm.Tabs[0]);

        Assert.Empty(_vm.Tabs);
        Assert.Equal("persisted", File.ReadAllText(path));
    }

    [Fact]
    public async Task CloseTab_DirtyCancel_KeepsTab()
    {
        var path = NewFile("k.txt", "original");
        await _vm.OpenFileAsync(path, CancellationToken.None);
        _vm.Tabs[0].DocumentText = "changed";
        _promptAnswers.Enqueue(SaveChangesResult.Cancel);

        await _vm.CloseTabCommand.ExecuteAsync(_vm.Tabs[0]);

        Assert.Single(_vm.Tabs);
    }

    [Fact]
    public async Task CloseTab_Clean_RemovesWithoutPrompt()
    {
        var path = NewFile("cl.txt", "clean");
        await _vm.OpenFileAsync(path, CancellationToken.None);

        await _vm.CloseTabCommand.ExecuteAsync(_vm.Tabs[0]);

        Assert.Empty(_vm.Tabs);
    }

    [Fact]
    public async Task NextTab_CyclesForward()
    {
        var a = NewFile("a.txt", "1");
        var b = NewFile("b.txt", "2");
        await _vm.OpenFileAsync(a, CancellationToken.None);
        await _vm.OpenFileAsync(b, CancellationToken.None);
        Assert.Same(_vm.Tabs[1], _vm.SelectedTab);

        _vm.NextTabCommand.Execute(null);
        Assert.Same(_vm.Tabs[0], _vm.SelectedTab);

        _vm.NextTabCommand.Execute(null);
        Assert.Same(_vm.Tabs[1], _vm.SelectedTab);
    }

    [Fact]
    public async Task PreviousTab_CyclesBackward()
    {
        var a = NewFile("a.txt", "1");
        var b = NewFile("b.txt", "2");
        await _vm.OpenFileAsync(a, CancellationToken.None);
        await _vm.OpenFileAsync(b, CancellationToken.None);

        _vm.PreviousTabCommand.Execute(null);
        Assert.Same(_vm.Tabs[0], _vm.SelectedTab);

        _vm.PreviousTabCommand.Execute(null);
        Assert.Same(_vm.Tabs[1], _vm.SelectedTab);
    }

    [Fact]
    public async Task Quit_NoDirtyTabs_Completes()
    {
        var path = NewFile("q.txt", "clean");
        await _vm.OpenFileAsync(path, CancellationToken.None);

        await _vm.QuitCommand.ExecuteAsync(null);

        Assert.True(_vm.IsCompleted);
    }

    [Fact]
    public async Task Quit_DirtyCancel_DoesNotComplete()
    {
        var path = NewFile("qc.txt", "original");
        await _vm.OpenFileAsync(path, CancellationToken.None);
        _vm.Tabs[0].DocumentText = "changed";
        _promptAnswers.Enqueue(SaveChangesResult.Cancel);

        await _vm.QuitCommand.ExecuteAsync(null);

        Assert.False(_vm.IsCompleted);
        Assert.Single(_vm.Tabs);
    }

    [Fact]
    public async Task Quit_DirtySaveAll_CompletesAfterSaving()
    {
        var path = NewFile("qs.txt", "original");
        await _vm.OpenFileAsync(path, CancellationToken.None);
        _vm.Tabs[0].DocumentText = "saved";
        _promptAnswers.Enqueue(SaveChangesResult.Save);

        await _vm.QuitCommand.ExecuteAsync(null);

        Assert.True(_vm.IsCompleted);
        Assert.Equal("saved", File.ReadAllText(path));
    }
}