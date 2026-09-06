using McGui.Core.Models;

namespace McGui.Core.Tests.Models;

public class CopyMoveOptionsTests
{
    [Fact]
    public void Default_HasSpecDefinedValues()
    {
        Assert.False(CopyMoveOptions.Default.PreserveAttributes);
        Assert.True(CopyMoveOptions.Default.FollowSymlinks);
    }
}