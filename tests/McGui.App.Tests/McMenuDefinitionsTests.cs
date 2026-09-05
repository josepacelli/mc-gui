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
