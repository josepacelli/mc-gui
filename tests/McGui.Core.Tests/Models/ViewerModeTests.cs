using McGui.Core.Models;

namespace McGui.Core.Tests.Models;

public class ViewerModeTests
{
    [Fact]
    public void HasTextAndHexValues()
    {
        Assert.Equal(0, (int)ViewerMode.Text);
        Assert.Equal(1, (int)ViewerMode.Hex);
    }
}