using System.IO;

namespace McGui.App.Tests;

public class PanelViewNativeStyleTests
{
    private static string PanelViewAxaml
    {
        get
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir is not null)
            {
                if (File.Exists(Path.Combine(dir.FullName, "McGui.sln")))
                {
                    return Path.Combine(dir.FullName, "src", "McGui.App", "Views", "PanelView.axaml");
                }

                dir = dir.Parent;
            }

            throw new InvalidOperationException("Could not locate repo root from " + AppContext.BaseDirectory);
        }
    }

    private static string Content => File.ReadAllText(PanelViewAxaml);

    [Fact]
    public void ListBox_HasNativeClassBoundToIsMacOS()
    {
        Assert.Contains("Classes.native=\"{Binding IsMacOS}\"", Content);
    }

    [Fact]
    public void NativeStyle_UsesHoverBrushOnPointerOver()
    {
        Assert.Contains("Selector=\"ListBox.native ListBoxItem:pointerover\"", Content);
        var start = Content.IndexOf("Selector=\"ListBox.native ListBoxItem:pointerover\"", StringComparison.Ordinal);
        var block = Content[start..(start + 200)];
        Assert.Contains("{DynamicResource NativeListHoverBrush}", block);
    }

    [Fact]
    public void NativeStyle_UsesSelectedBrushOnSelected()
    {
        Assert.Contains("Selector=\"ListBox.native ListBoxItem:selected\"", Content);
        var start = Content.IndexOf("Selector=\"ListBox.native ListBoxItem:selected\"", StringComparison.Ordinal);
        var block = Content[start..(start + 200)];
        Assert.Contains("{DynamicResource NativeListSelectedBrush}", block);
    }

    [Fact]
    public void NativeStyle_DoesNotIntroduceAlternationCount()
    {
        Assert.DoesNotContain("AlternationCount", Content);
    }
}
