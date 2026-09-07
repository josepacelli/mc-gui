using System.IO;

namespace McGui.App.Tests;

public class EditorWindowStructureTests
{
    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            if (File.Exists(Path.Combine(dir.FullName, "McGui.sln")))
            {
                return dir.FullName;
            }

            dir = dir.Parent;
        }

        throw new InvalidOperationException("Could not locate repo root from " + AppContext.BaseDirectory);
    }

    private static string EditorAxaml => Path.Combine(RepoRoot(), "src", "McGui.App", "Views", "EditorWindow.axaml");

    [Fact]
    public void ReferencesAvaloniaEditNamespace()
    {
        var content = File.ReadAllText(EditorAxaml);
        Assert.Contains("clr-namespace:AvaloniaEdit;assembly=AvaloniaEdit", content);
    }

    [Fact]
    public void Toolbar_HasTenFunctionKeysWithEditorLabels()
    {
        var content = File.ReadAllText(EditorAxaml);
        foreach (var label in new[] { "F1 Help", "F2 Save", "F3 Find", "F4 Replace", "F5 Macro", "F6 Block", "F7 Spell", "F8 Config", "F9 Menu", "F10 Quit" })
        {
            Assert.Contains($"Content=\"{label}\"", content);
        }
    }

    [Fact]
    public void HasTabControl()
    {
        var content = File.ReadAllText(EditorAxaml);
        Assert.Contains("<TabControl", content);
    }

    [Fact]
    public void HasSearchAndReplaceInputs()
    {
        var content = File.ReadAllText(EditorAxaml);
        Assert.Contains("x:Name=\"SearchTextBox\"", content);
        Assert.Contains("x:Name=\"ReplaceTextBox\"", content);
        Assert.Contains("x:Name=\"RegexToggle\"", content);
        Assert.Contains("x:Name=\"CaseToggle\"", content);
        Assert.Contains("x:Name=\"WholeWordToggle\"", content);
    }

    [Fact]
    public void HasStatusBarForEncodingReadOnlyAndPosition()
    {
        var content = File.ReadAllText(EditorAxaml);
        Assert.Contains("x:Name=\"StatusEncoding\"", content);
        Assert.Contains("x:Name=\"StatusReadOnly\"", content);
        Assert.Contains("x:Name=\"StatusPosition\"", content);
    }

    [Fact]
    public void AppAxaml_IncludesAvaloniaEditStyles()
    {
        var app = Path.Combine(RepoRoot(), "src", "McGui.App", "App.axaml");
        var content = File.ReadAllText(app);
        Assert.Contains("avares://AvaloniaEdit/Themes/Fluent/AvaloniaEdit.xaml", content);
    }
}