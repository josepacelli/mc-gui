using System.IO;
using McGui.App;

namespace McGui.App.Tests;

public class McMenuDefinitionsTests
{
    private static readonly string[] FileItemsExpected =
    [
        "View", "View file...", "Filtered view", "Edit", "Copy", "Chmod", "Link", "Symlink",
        "Relative symlink", "Edit symlink", "Chown", "Advanced chown", "Chattr", "Rename/Move",
        "Mkdir", "Delete", "Quick cd", "--", "Select group", "Unselect group", "Invert selection",
        "--", "Exit",
    ];

    private static readonly string[] CommandItemsExpected =
    [
        "User menu", "Directory tree", "Find file", "Swap panels", "Switch panels on/off",
        "Compare directories", "Compare files", "External panelize", "Show directory sizes", "--",
        "Command history", "Viewed/edited files history", "Directory hotlist", "Active VFS list",
        "Background jobs", "Screen list", "--", "Edit extension file", "Edit menu file",
        "Edit highlighting group file",
    ];

    private static readonly string[] OptionsItemsExpected =
    [
        "Configuration...", "Layout...", "Panel options...", "Confirmation...", "Appearance...",
        "Learn keys...", "Virtual FS...", "--", "Save setup", "--", "About...", "--", "Theme",
    ];

    private static readonly string[] PanelItemsExpected =
    [
        "File listing", "Quick view", "Info", "Tree", "Panelize", "--", "Listing format...",
        "Sort order...", "Filter...", "Encoding...", "--", "FTP link...", "Shell link...",
        "SFTP link...", "--", "Rescan",
    ];

    private static string[] Texts(IReadOnlyList<McMenuItem> items) =>
        items.Select(i => i.IsSeparator ? "--" : i.Text).ToArray();

    private static string[] EnabledTexts(IReadOnlyList<McMenuItem> items) =>
        items.Where(i => !i.IsSeparator && i.IsEnabled).Select(i => i.Text).ToArray();

    [Fact]
    public void Menus_ExposeTopLevelInMcOrder()
    {
        Assert.Equal(["Left", "File", "Command", "Options", "Right"], McMenuDefinitions.Menus.Select(m => m.Name));
    }

    [Theory]
    [InlineData("Left")]
    [InlineData("Right")]
    public void PanelMenu_ItemsMatchOriginal(string menuName)
    {
        Assert.Equal(PanelItemsExpected, Texts(McMenuDefinitions.ForMenu(menuName)));
    }

    [Fact]
    public void RightMenu_IsSameAsLeftMenu()
    {
        Assert.Equal(
            Texts(McMenuDefinitions.ForMenu("Left")),
            Texts(McMenuDefinitions.ForMenu("Right")));
    }

    [Fact]
    public void FileMenu_ItemsMatchOriginal()
    {
        Assert.Equal(FileItemsExpected, Texts(McMenuDefinitions.ForMenu("File")));
    }

    [Fact]
    public void CommandMenu_ItemsMatchOriginal()
    {
        Assert.Equal(CommandItemsExpected, Texts(McMenuDefinitions.ForMenu("Command")));
    }

    [Fact]
    public void OptionsMenu_ItemsMatchOriginalPlusTheme()
    {
        Assert.Equal(OptionsItemsExpected, Texts(McMenuDefinitions.ForMenu("Options")));
    }

    [Fact]
    public void EnabledFileItems_AreTheExpectedOperations()
    {
        Assert.Equal(
            ["Copy", "Rename/Move", "Mkdir", "Delete", "Select group", "Unselect group", "Invert selection", "Exit"],
            EnabledTexts(McMenuDefinitions.ForMenu("File")));
    }

    [Fact]
    public void Options_OnlyThemeIsEnabled()
    {
        Assert.Equal(["Theme"], EnabledTexts(McMenuDefinitions.ForMenu("Options")));
    }

    [Fact]
    public void CommandMenu_NoItemIsEnabled()
    {
        Assert.Empty(EnabledTexts(McMenuDefinitions.ForMenu("Command")));
    }

    [Fact]
    public void PanelMenus_OnlyRescanIsEnabled()
    {
        Assert.Equal(["Rescan"], EnabledTexts(McMenuDefinitions.ForMenu("Left")));
        Assert.Equal(["Rescan"], EnabledTexts(McMenuDefinitions.ForMenu("Right")));
    }

    [Theory]
    [InlineData("File", "View")]
    [InlineData("File", "Edit")]
    [InlineData("File", "Chmod")]
    [InlineData("File", "Link")]
    [InlineData("File", "Quick cd")]
    [InlineData("Command", "User menu")]
    [InlineData("Command", "Find file")]
    [InlineData("Command", "Directory hotlist")]
    [InlineData("Options", "Configuration...")]
    [InlineData("Left", "Quick view")]
    [InlineData("Left", "Info")]
    [InlineData("Left", "Tree")]
    [InlineData("Left", "Panelize")]
    public void UnimplementedFeatureItems_AreDisabled(string menu, string text)
    {
        var item = McMenuDefinitions.ForMenu(menu).Single(i => !i.IsSeparator && i.Text == text);
        Assert.False(item.IsEnabled);
    }

    [Fact]
    public void Mnemonics_AreParsedFromAmpersandText()
    {
        Assert.Equal('C', McMenuDefinitions.ForMenu("File").First(i => i.Text == "Copy").Mnemonic);
        Assert.Equal('x', McMenuDefinitions.ForMenu("File").First(i => i.Text == "Exit").Mnemonic);
        Assert.Equal('T', McMenuDefinitions.ForMenu("Options").First(i => i.Text == "Theme").Mnemonic);
    }
}

public class MainWindowMenuBarStructureTests
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

    [Fact]
    public void MenuBar_HasFiveTopLevelMenusInOrder()
    {
        var content = File.ReadAllText(MainWindowAxaml);
        var menuBlock = content.Split("<MenuItem Header=\"_Left\">", 2)[1].Split("</Menu>", 2)[0];

        Assert.Contains("Header=\"_Left\"", content);
        Assert.Contains("Header=\"_Right\"", content);
        Assert.True(menuBlock.IndexOf("Header=\"_File\"", StringComparison.Ordinal)
                     < menuBlock.IndexOf("Header=\"_Command\"", StringComparison.Ordinal));
        Assert.True(menuBlock.IndexOf("Header=\"_Command\"", StringComparison.Ordinal)
                     < menuBlock.IndexOf("Header=\"_Options\"", StringComparison.Ordinal));
    }

    [Fact]
    public void Theme_MenuLivesInsideOptions_NotTopLevel()
    {
        var content = File.ReadAllText(MainWindowAxaml);
        var optionsBlock = content.Split("<MenuItem Header=\"_Options\">", 2)[1].Split("<MenuItem Header=\"_Right\">", 2)[0];

        Assert.Contains("Header=\"_Theme\"", optionsBlock);
        Assert.DoesNotContain("<MenuItem Header=\"_Theme\"", content.Split("<MenuItem Header=\"_Left\">", 2)[0]);
    }

    [Fact]
    public void DisabledMenuItems_HaveIsEnabledFalse()
    {
        var content = File.ReadAllText(MainWindowAxaml);
        Assert.Contains("<MenuItem Header=\"View\" IsEnabled=\"False\"", content);
        Assert.Contains("<MenuItem Header=\"Edit\" IsEnabled=\"False\"", content);
        Assert.Contains("<MenuItem Header=\"Find file\" IsEnabled=\"False\"", content);
        Assert.Contains("<MenuItem Header=\"Configuration...\" IsEnabled=\"False\"", content);
    }

    [Fact]
    public void EnabledMenuItems_HaveCommands()
    {
        var content = File.ReadAllText(MainWindowAxaml);
        Assert.Contains("<MenuItem Header=\"Copy\" Command=\"{Binding RequestCopyCommand}\"", content);
        Assert.Contains("<MenuItem Header=\"Rescan\" Command=\"{Binding RescanActivePanelCommand}\"", content);
        Assert.Contains("<MenuItem Header=\"Exit\" Click=\"OnExitClick\"", content);
    }
}
