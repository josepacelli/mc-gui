using System.Runtime.Versioning;
using McGui.App.ViewModels;
using McGui.Infrastructure.macOS;

namespace McGui.App.Tests.ViewModels;

[SupportedOSPlatform("macos")]
public class EditorTabViewModelTests
{
    [Fact]
    public void Constructor_TitleIsFileNameWithoutDirty()
    {
        var tab = new EditorTabViewModel(new MacEditorService(), "/dir/readme.txt", "hi", "UTF-8", false, false);

        Assert.Equal("readme.txt", tab.Title);
        Assert.Equal("readme.txt", tab.FileName);
        Assert.False(tab.IsDirty);
    }

    [Fact]
    public void EditingText_MarksDirtyAndAppendsStarToTitle()
    {
        var tab = new EditorTabViewModel(new MacEditorService(), "/dir/readme.txt", "hi", "UTF-8", false, false);

        tab.DocumentText = "hello";

        Assert.True(tab.IsDirty);
        Assert.Equal("readme.txt *", tab.Title);
    }

    [Fact]
    public void RevertingTextToOriginal_ClearsDirty()
    {
        var tab = new EditorTabViewModel(new MacEditorService(), "/dir/readme.txt", "hi", "UTF-8", false, false);

        tab.DocumentText = "changed";
        Assert.True(tab.IsDirty);

        tab.DocumentText = "hi";
        Assert.False(tab.IsDirty);
    }

    [Fact]
    public void MarkSaved_ClearsDirtyAndResetsComparisonBase()
    {
        var tab = new EditorTabViewModel(new MacEditorService(), "/dir/readme.txt", "hi", "UTF-8", false, false);

        tab.DocumentText = "new base";
        tab.MarkSaved();
        Assert.False(tab.IsDirty);

        tab.DocumentText = "new base edited";
        Assert.True(tab.IsDirty);

        tab.DocumentText = "new base";
        Assert.False(tab.IsDirty);
    }
}