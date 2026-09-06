using System.IO;

namespace McGui.App.Tests;

public class CopyMoveDialogStructureTests
{
    private static string CopyMoveDialogAxaml
    {
        get
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir is not null)
            {
                if (File.Exists(Path.Combine(dir.FullName, "McGui.sln")))
                {
                    return Path.Combine(dir.FullName, "src", "McGui.App", "Views", "CopyMoveDialog.axaml");
                }

                dir = dir.Parent;
            }

            throw new InvalidOperationException("Could not locate repo root from " + AppContext.BaseDirectory);
        }
    }

    [Fact]
    public void PreserveAttributes_CheckboxPresentInXaml()
    {
        var content = File.ReadAllText(CopyMoveDialogAxaml);

        Assert.Contains("Preservar atributos", content);
        Assert.Contains("IsChecked=\"{Binding PreserveAttributes}\"", content);
    }

    [Fact]
    public void FollowSymlinks_CheckboxPresentInXaml()
    {
        var content = File.ReadAllText(CopyMoveDialogAxaml);

        Assert.Contains("Seguir links", content);
        Assert.Contains("IsChecked=\"{Binding FollowSymlinks}\"", content);
    }
}