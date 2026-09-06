using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace McGui.App.Tests.Theming;

public class ThemeResourcesTests
{
    private static readonly string RepoRoot = FindRepoRoot();

    private static readonly string[] ExpectedTokens =
    [
        "PanelBorderBrush",
        "PanelBorderActiveBrush",
        "OverlayLoadingBackgroundBrush",
        "OverlayLoadingForegroundBrush",
        "OverlayErrorBackgroundBrush",
        "OverlayErrorForegroundBrush",
        "TextErrorBrush",
        "TextWarningBrush",
        "FolderIconBrush",
        "FileIconBrush",
        "NativeListHoverBrush",
        "NativeListSelectedBrush",
        "NativeToolbarBackgroundBrush",
        "NativeToolbarButtonForegroundBrush",
    ];

    private static readonly Regex HexColor = new(@"#[0-9A-Fa-f]{6,8}", RegexOptions.Compiled);

    private static readonly string[] NamedColors =
    [
        "AliceBlue", "AntiqueWhite", "Aqua", "Aquamarine", "Azure", "Beige", "Bisque", "Black",
        "BlanchedAlmond", "Blue", "BlueViolet", "Brown", "BurlyWood", "CadetBlue", "Chartreuse",
        "Chocolate", "Coral", "CornflowerBlue", "Cornsilk", "Crimson", "Cyan", "DarkBlue",
        "DarkCyan", "DarkGoldenrod", "DarkGray", "DarkGreen", "DarkKhaki", "DarkMagenta",
        "DarkOliveGreen", "DarkOrange", "DarkOrchid", "DarkRed", "DarkSalmon", "DarkSeaGreen",
        "DarkSlateBlue", "DarkSlateGray", "DarkTurquoise", "DarkViolet", "DeepPink", "DeepSkyBlue",
        "DimGray", "DodgerBlue", "Firebrick", "FloralWhite", "ForestGreen", "Fuchsia", "Gainsboro",
        "GhostWhite", "Gold", "Goldenrod", "Gray", "Green", "GreenYellow", "Honeydew", "HotPink",
        "IndianRed", "Indigo", "Ivory", "Khaki", "Lavender", "LavenderBlush", "LawnGreen",
        "LemonChiffon", "LightBlue", "LightCoral", "LightCyan", "LightGoldenrodYellow", "LightGray",
        "LightGreen", "LightPink", "LightSalmon", "LightSeaGreen", "LightSkyBlue", "LightSlateGray",
        "LightSteelBlue", "LightYellow", "Lime", "LimeGreen", "Linen", "Magenta", "Maroon",
        "MediumAquamarine", "MediumBlue", "MediumOrchid", "MediumPurple", "MediumSeaGreen",
        "MediumSlateBlue", "MediumSpringGreen", "MediumTurquoise", "MediumVioletRed", "MidnightBlue",
        "MintCream", "MistyRose", "Moccasin", "NavajoWhite", "Navy", "OldLace", "Olive", "OliveDrab",
        "Orange", "OrangeRed", "Orchid", "PaleGoldenrod", "PaleGreen", "PaleTurquoise",
        "PaleVioletRed", "PapayaWhip", "PeachPuff", "Peru", "Pink", "Plum", "PowderBlue", "Purple",
        "Red", "RosyBrown", "RoyalBlue", "SaddleBrown", "Salmon", "SandyBrown", "SeaGreen",
        "SeaShell", "Sienna", "Silver", "SkyBlue", "SlateBlue", "SlateGray", "Snow", "SpringGreen",
        "SteelBlue", "Tan", "Teal", "Thistle", "Tomato", "Transparent", "Turquoise", "Violet",
        "Wheat", "White", "WhiteSmoke", "Yellow", "YellowGreen",
    ];

    private static string FindRepoRoot()
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

        throw new InvalidOperationException("Could not locate McGui.sln above " + AppContext.BaseDirectory);
    }

    private static string ThemeFile => Path.Combine(RepoRoot, "src", "McGui.App", "Themes.axaml");

    private static IEnumerable<string> ViewFiles()
    {
        var views = Path.Combine(RepoRoot, "src", "McGui.App", "Views");
        foreach (var file in Directory.EnumerateFiles(views, "*.axaml").OrderBy(f => f))
        {
            yield return file;
        }

        yield return Path.Combine(RepoRoot, "src", "McGui.App", "MainWindow.axaml");
    }

    [Fact]
    public void ThemeFile_DefinesEverySemanticTokenInBothLightAndDarkVariants()
    {
        var content = File.ReadAllText(ThemeFile);

        Assert.Contains("<ResourceDictionary x:Key=\"Light\">", content);
        Assert.Contains("<ResourceDictionary x:Key=\"Dark\">", content);

        foreach (var token in ExpectedTokens)
        {
            Assert.Matches($@"x:Key=""{token}""", content);
        }

        var lightSection = content.Split("x:Key=\"Light\"", 2)[1].Split("</ResourceDictionary>", 2)[0];
        var darkSection = content.Split("x:Key=\"Dark\"", 2)[1].Split("</ResourceDictionary>", 2)[0];

        foreach (var token in ExpectedTokens)
        {
            Assert.Matches($@"x:Key=""{token}""", lightSection);
            Assert.Matches($@"x:Key=""{token}""", darkSection);
        }
    }

    [Fact]
    public void ThemeFile_EveryTokenHasDistinctValuePerVariant()
    {
        var content = File.ReadAllText(ThemeFile);
        var lightSection = content.Split("x:Key=\"Light\"", 2)[1].Split("</ResourceDictionary>", 2)[0];
        var darkSection = content.Split("x:Key=\"Dark\"", 2)[1].Split("</ResourceDictionary>", 2)[0];
        var tokenColor = new Regex($@"<SolidColorBrush x:Key=""([A-Za-z]+)"" Color=""([^""]+)""", RegexOptions.Compiled);

        var lightValues = ValuesByToken(lightSection);
        var darkValues = ValuesByToken(darkSection);

        foreach (var token in ExpectedTokens)
        {
            var light = lightValues[token];
            var dark = darkValues[token];
            Assert.False(
                string.Equals(light, dark, StringComparison.OrdinalIgnoreCase),
                $"Token {token} has the same value ({light}) in Light and Dark; variants must differ (THM-01)");
        }

        Dictionary<string, string> ValuesByToken(string section)
        {
            var values = new Dictionary<string, string>();
            foreach (Match match in tokenColor.Matches(section))
            {
                values[match.Groups[1].Value] = match.Groups[2].Value;
            }

            return values;
        }
    }

    [Fact]
    public void EveryTokenUsedByViews_IsDefinedInThePalette()
    {
        var palette = File.ReadAllText(ThemeFile);
        var definedTokens = ExpectedTokens.ToHashSet();
        var usedTokens = new HashSet<string>();
        var dynamicResource = new Regex(@"\{DynamicResource ([A-Za-z]+)\}", RegexOptions.Compiled);

        foreach (var view in ViewFiles())
        {
            var content = File.ReadAllText(view);
            foreach (Match match in dynamicResource.Matches(content))
            {
                usedTokens.Add(match.Groups[1].Value);
            }
        }

        foreach (var token in usedTokens)
        {
            Assert.True(
                definedTokens.Contains(token),
                $"View references {token}, which is not defined in {ThemeFile}");
            Assert.True(palette.Contains(token), $"Token {token} missing from {ThemeFile}");
        }
    }

    [Fact]
    public void NoViewDefinesALiteralColorOnAVisualProperty()
    {
        var visualProperty = new Regex(@"(?:Background|Foreground|BorderBrush)\s*=\s*""([^""{}]+)""", RegexOptions.Compiled);
        var visualSetter = new Regex(@"Property=""(Background|Foreground|BorderBrush)""\s+Value=""([^""{}]+)""", RegexOptions.Compiled);
        var failures = new List<string>();

        foreach (var view in ViewFiles())
        {
            var lines = File.ReadAllLines(view);
            for (var i = 0; i < lines.Length; i++)
            {
                var line = lines[i];
                if (line.TrimStart().StartsWith("<!--") || line.Contains("<!--"))
                {
                    continue;
                }

                foreach (Match match in visualProperty.Matches(line))
                {
                    var value = match.Groups[1].Value;
                    if (HexColor.IsMatch(value))
                    {
                        failures.Add($"{Path.GetFileName(view)}:{i + 1} hex color {value} on a visual property");
                        continue;
                    }

                    var named = NamedColors.FirstOrDefault(n => string.Equals(n, value, StringComparison.OrdinalIgnoreCase));
                    if (named is not null)
                    {
                        failures.Add($"{Path.GetFileName(view)}:{i + 1} named color {value} on a visual property");
                    }
                }

                foreach (Match match in visualSetter.Matches(line))
                {
                    var value = match.Groups[2].Value;
                    if (HexColor.IsMatch(value))
                    {
                        failures.Add($"{Path.GetFileName(view)}:{i + 1} hex color {value} on {match.Groups[1].Value} setter");
                        continue;
                    }

                    var named = NamedColors.FirstOrDefault(n => string.Equals(n, value, StringComparison.OrdinalIgnoreCase));
                    if (named is not null)
                    {
                        failures.Add($"{Path.GetFileName(view)}:{i + 1} named color {value} on {match.Groups[1].Value} setter");
                    }
                }
            }
        }

        Assert.True(
            failures.Count == 0,
            "Literal colors found on visual properties:\n  " + string.Join("\n  ", failures));
    }
}
