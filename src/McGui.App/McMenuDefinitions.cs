using System;
using System.Collections.Generic;
using System.Linq;

namespace McGui.App;

public sealed record McMenuItem(string Text, char? Mnemonic, bool IsSeparator, bool IsEnabled, string? CommandName = null)
{
    public static McMenuItem Separator() => new(string.Empty, null, IsSeparator: true, IsEnabled: false);

    public static McMenuItem Item(string textWithAmpersand, string? commandName = null)
    {
        var amp = textWithAmpersand.IndexOf('&');
        var text = amp >= 0 ? textWithAmpersand.Remove(amp, 1) : textWithAmpersand;
        var mnemonic = amp >= 0 && amp < textWithAmpersand.Length - 1 ? textWithAmpersand[amp + 1] : (char?)null;
        return new McMenuItem(text, mnemonic, IsSeparator: false, IsEnabled: commandName is not null, commandName);
    }
}

public sealed record McMenu(string Name, string Header, IReadOnlyList<McMenuItem> Items);

public static class McMenuDefinitions
{
    public static IReadOnlyList<McMenu> Menus { get; } = Build();

    private static IReadOnlyList<McMenu> Build()
    {
        var leftItems = LeftItems();
        var fileItems = FileItems();
        var commandItems = CommandItems();
        var optionsItems = OptionsItems();
        return
        [
            new McMenu("Left", "Left", leftItems),
            new McMenu("File", "File", fileItems),
            new McMenu("Command", "Command", commandItems),
            new McMenu("Options", "Options", optionsItems),
            new McMenu("Right", "Right", leftItems),
        ];
    }

    private static IReadOnlyList<McMenuItem> LeftItems() => PanelItems();

    private static IReadOnlyList<McMenuItem> PanelItems() =>
    [
        McMenuItem.Item("File listin&g"),
        McMenuItem.Item("&Quick view"),
        McMenuItem.Item("&Info"),
        McMenuItem.Item("&Tree"),
        McMenuItem.Item("Paneli&ze"),
        McMenuItem.Separator(),
        McMenuItem.Item("&Listing format..."),
        McMenuItem.Item("&Sort order..."),
        McMenuItem.Item("&Filter..."),
        McMenuItem.Item("&Encoding..."),
        McMenuItem.Separator(),
        McMenuItem.Item("FT&P link..."),
        McMenuItem.Item("S&hell link..."),
        McMenuItem.Item("SFTP li&nk..."),
        McMenuItem.Separator(),
        McMenuItem.Item("&Rescan", "Refresh"),
    ];

    private static IReadOnlyList<McMenuItem> FileItems() =>
    [
        McMenuItem.Item("&View", "View"),
        McMenuItem.Item("Vie&w file..."),
        McMenuItem.Item("&Filtered view"),
        McMenuItem.Item("&Edit", "Edit"),
        McMenuItem.Item("&Copy", "Copy"),
        McMenuItem.Item("C&hmod"),
        McMenuItem.Item("&Link"),
        McMenuItem.Item("&Symlink"),
        McMenuItem.Item("Relative symlin&k"),
        McMenuItem.Item("Edit s&ymlink"),
        McMenuItem.Item("Ch&own"),
        McMenuItem.Item("&Advanced chown"),
        McMenuItem.Item("Cha&ttr"),
        McMenuItem.Item("&Rename/Move", "Rename/Move"),
        McMenuItem.Item("&Mkdir", "Mkdir"),
        McMenuItem.Item("&Delete", "Delete"),
        McMenuItem.Item("&Quick cd"),
        McMenuItem.Separator(),
        McMenuItem.Item("Select &group", "Select group"),
        McMenuItem.Item("U&nselect group", "Unselect group"),
        McMenuItem.Item("&Invert selection", "Invert selection"),
        McMenuItem.Separator(),
        McMenuItem.Item("E&xit", "Exit"),
    ];

    private static IReadOnlyList<McMenuItem> CommandItems() =>
    [
        McMenuItem.Item("&User menu"),
        McMenuItem.Item("&Directory tree"),
        McMenuItem.Item("&Find file"),
        McMenuItem.Item("S&wap panels"),
        McMenuItem.Item("Switch &panels on/off"),
        McMenuItem.Item("&Compare directories"),
        McMenuItem.Item("C&ompare files"),
        McMenuItem.Item("E&xternal panelize"),
        McMenuItem.Item("Show directory s&izes"),
        McMenuItem.Separator(),
        McMenuItem.Item("Command &history"),
        McMenuItem.Item("Viewed/edited files hi&story"),
        McMenuItem.Item("Di&rectory hotlist"),
        McMenuItem.Item("&Active VFS list"),
        McMenuItem.Item("&Background jobs"),
        McMenuItem.Item("Screen lis&t"),
        McMenuItem.Separator(),
        McMenuItem.Item("Edit &extension file"),
        McMenuItem.Item("Edit &menu file"),
        McMenuItem.Item("Edit hi&ghlighting group file"),
    ];

    private static IReadOnlyList<McMenuItem> OptionsItems()
    {
        var items = new List<McMenuItem>
        {
            McMenuItem.Item("&Configuration..."),
            McMenuItem.Item("&Layout..."),
            McMenuItem.Item("&Panel options..."),
            McMenuItem.Item("C&onfirmation..."),
            McMenuItem.Item("&Appearance..."),
            McMenuItem.Item("Learn &keys..."),
            McMenuItem.Item("&Virtual FS..."),
            McMenuItem.Separator(),
            McMenuItem.Item("&Save setup"),
            McMenuItem.Separator(),
            McMenuItem.Item("A&bout..."),
        };

        items.Add(McMenuItem.Separator());
        items.Add(McMenuItem.Item("&Theme", "Theme"));
        return items;
    }

    public static IReadOnlyList<McMenuItem> ForMenu(string name) =>
        Menus.First(m => m.Name == name).Items;
}
