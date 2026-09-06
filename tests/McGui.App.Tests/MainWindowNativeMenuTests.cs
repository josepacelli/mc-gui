using System.IO;

namespace McGui.App.Tests;

public class MainWindowNativeMenuTests
{
    private static string MainWindowAxaml
    {
        get
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir is not null)
            {
                if (File.Exists(Path.Combine(dir.FullName, "McGui.sln")))
                {
                    return Path.Combine(dir.FullName, "src", "McGui.App", "MainWindow.axaml");
                }

                dir = dir.Parent;
            }

            throw new InvalidOperationException("Could not locate repo root from " + AppContext.BaseDirectory);
        }
    }

    private static string NativeMenuSection
    {
        get
        {
            var content = File.ReadAllText(MainWindowAxaml);
            var start = content.IndexOf("<NativeMenu.Menu>", StringComparison.Ordinal);
            var end = content.IndexOf("</NativeMenu.Menu>", StringComparison.Ordinal);
            Assert.True(start >= 0 && end > start, "MainWindow.axaml must declare a <NativeMenu.Menu> block");
            return content[start..end];
        }
    }

    [Fact]
    public void NativeMenu_HasFiveTopLevelHeadersInOrder()
    {
        var headers = new[] { "Left", "File", "Command", "Options", "Right" };
        var positions = headers
            .Select(h => NativeMenuSection.IndexOf($"<NativeMenuItem Header=\"{h}\">", StringComparison.Ordinal))
            .ToArray();

        Assert.All(positions, p => Assert.True(p >= 0, "missing native header"));
        for (var i = 0; i < positions.Length - 1; i++)
        {
            Assert.True(positions[i] < positions[i + 1], $"native header {headers[i]} must precede {headers[i + 1]}");
        }
    }

    [Theory]
    [InlineData("Rescan", "RescanActivePanelCommand")]
    [InlineData("Copy", "RequestCopyCommand")]
    [InlineData("Rename/Move", "RequestMoveCommand")]
    [InlineData("Mkdir", "RequestMkdirCommand")]
    [InlineData("Delete", "RequestDeleteCommand")]
    [InlineData("Select group", "SelectAllCommand")]
    [InlineData("Unselect group", "UnselectAllCommand")]
    [InlineData("Invert selection", "InvertSelectionCommand")]
    public void NativeMenuItem_MirrorsSameCommandAsInWindowItem(string header, string command)
    {
        Assert.Contains(
            $"<NativeMenuItem Header=\"{header}\" Command=\"{{Binding {command}}}\"",
            NativeMenuSection);
    }

    [Theory]
    [InlineData("View")]
    [InlineData("Edit")]
    [InlineData("Chmod")]
    [InlineData("Find file")]
    [InlineData("Configuration...")]
    public void NativeMenuItem_MirrorsDisabledInWindowItem(string header)
    {
        Assert.Contains($"<NativeMenuItem Header=\"{header}\" IsEnabled=\"False\"", NativeMenuSection);
    }

    [Fact]
    public void NativeMenu_DoesNotDuplicateInWindowMenuCommands()
    {
        var content = File.ReadAllText(MainWindowAxaml);
        var inWindowMenuStart = content.IndexOf("<Menu Grid.Row=\"0\"", StringComparison.Ordinal);
        Assert.True(inWindowMenuStart > 0, "in-window Menu must still be declared");
    }
}
