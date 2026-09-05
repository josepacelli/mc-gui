namespace McGui.App.Tests;

public class FileSizeFormatterTests
{
    [Theory]
    [InlineData(0, "0 B")]
    [InlineData(1, "1 B")]
    [InlineData(500, "500 B")]
    [InlineData(1023, "1023 B")]
    public void Format_BelowOneKib_ShowsBytes(long bytes, string expected) =>
        Assert.Equal(expected, FileSizeFormatter.Format(bytes));

    [Theory]
    [InlineData(1024, "1 kB")]
    [InlineData(1536, "1.5 kB")]
    [InlineData(1024 * 1024, "1 MB")]
    [InlineData((long)(1.5 * 1024 * 1024), "1.5 MB")]
    [InlineData(1024L * 1024 * 1024, "1 GB")]
    [InlineData((long)(1024L * 1024 * 1024 * 1.9), "1.9 GB")]
    [InlineData(1024L * 1024 * 1024 * 1024, "1 TB")]
    public void Format_UsesBinaryUnits(long bytes, string expected) =>
        Assert.Equal(expected, FileSizeFormatter.Format(bytes));

    [Fact]
    public void Format_WholeUnitValue_HasNoFractionalPart()
    {
        Assert.Equal("1 kB", FileSizeFormatter.Format(1024));
        Assert.DoesNotContain(".", FileSizeFormatter.Format(1024 * 1024));
    }

    [Fact]
    public void Format_NonWholeValue_HasAtMostOneDecimalDigit()
    {
        Assert.Equal("1.5 kB", FileSizeFormatter.Format(1536));
    }
}
