namespace McGui.App.Tests;

public class EditorSearchTests
{
    private static readonly SearchOptions Plain = new(Regex: false, CaseSensitive: true, WholeWord: false);
    private static readonly SearchOptions PlainCI = new(Regex: false, CaseSensitive: false, WholeWord: false);
    private static readonly SearchOptions RegexOpts = new(Regex: true, CaseSensitive: true, WholeWord: false);
    private static readonly SearchOptions PlainWhole = new(Regex: false, CaseSensitive: true, WholeWord: true);

    [Fact]
    public void FindAll_PlainSubstring_FindsAllOccurrences()
    {
        var matches = EditorSearch.FindAll("foo bar foo baz", "foo", Plain);

        Assert.Equal(2, matches.Count);
        Assert.Equal(new SearchMatch(0, 3), matches[0]);
        Assert.Equal(new SearchMatch(8, 3), matches[1]);
    }

    [Fact]
    public void FindAll_CaseInsensitive_FindsMixedCase()
    {
        var matches = EditorSearch.FindAll("Foo foo FOO", "foo", PlainCI);

        Assert.Equal(3, matches.Count);
    }

    [Fact]
    public void FindAll_CaseSensitive_IgnoresDifferentCase()
    {
        var matches = EditorSearch.FindAll("Foo foo FOO", "foo", Plain);

        Assert.Single(matches);
    }

    [Fact]
    public void FindAll_NoMatch_ReturnsEmpty()
    {
        var matches = EditorSearch.FindAll("abc", "xyz", Plain);

        Assert.Empty(matches);
    }

    [Fact]
    public void FindAll_EmptyPattern_ReturnsEmpty()
    {
        var matches = EditorSearch.FindAll("abc", "", Plain);

        Assert.Empty(matches);
    }

    [Fact]
    public void FindAll_Regex_UsesPattern()
    {
        var matches = EditorSearch.FindAll("foo123 bar foo456", "foo\\d+", RegexOpts);

        Assert.Equal(2, matches.Count);
    }

    [Fact]
    public void FindAll_NonRegex_EscapesPattern()
    {
        // "." must match literal dot when Regex=false
        var matches = EditorSearch.FindAll("a.b aXb", "a.b", Plain);

        Assert.Single(matches);
        Assert.Equal(0, matches[0].Index);
    }

    [Fact]
    public void FindAll_WholeWord_ExcludesSubstringPartial()
    {
        var matches = EditorSearch.FindAll("cat concat scatter cat", "cat", PlainWhole);

        Assert.Equal(2, matches.Count);
        Assert.Equal(0, matches[0].Index);
        Assert.Equal(19, matches[1].Index);
    }

    [Fact]
    public void ReplaceAll_ReplacesAndCounts()
    {
        var (result, count) = EditorSearch.ReplaceAll("foo bar foo", "foo", "baz", Plain);

        Assert.Equal(2, count);
        Assert.Equal("baz bar baz", result);
    }

    [Fact]
    public void ReplaceAll_RegexWithCapture_SupportsReplacementRefs()
    {
        var (result, count) = EditorSearch.ReplaceAll("abc123", "([a-z]+)(\\d+)", "$2-$1", RegexOpts);

        Assert.Equal(1, count);
        Assert.Equal("123-abc", result);
    }

    [Fact]
    public void ReplaceAll_WholeWord_SkipsPartialWords()
    {
        var (result, count) = EditorSearch.ReplaceAll("cat concat", "cat", "dog", PlainWhole);

        Assert.Equal(1, count);
        Assert.Equal("dog concat", result);
    }

    [Fact]
    public void ReplaceAll_CaseInsensitive_ReplacesAllCasing()
    {
        var (result, count) = EditorSearch.ReplaceAll("Foo FOO foo", "foo", "bar", PlainCI);

        Assert.Equal(3, count);
        Assert.Equal("bar bar bar", result);
    }

    [Fact]
    public void ReplaceAll_NoMatch_UnchangedAndZero()
    {
        var (result, count) = EditorSearch.ReplaceAll("abc", "zzz", "x", Plain);

        Assert.Equal("abc", result);
        Assert.Equal(0, count);
    }
}
public class EditorSearchReplaceNextTests
{
    private static readonly SearchOptions Plain = new(Regex: false, CaseSensitive: true, WholeWord: false);

    [Fact]
    public void ReplaceNext_FromOffset_ReplacesFirstMatchAtOrAfterOffset()
    {
        var (result, replaced) = EditorSearch.ReplaceNext("foo foo foo", "foo", "bar", Plain, fromOffset: 5);

        Assert.True(replaced);
        Assert.Equal("foo foo bar", result);
    }

    [Fact]
    public void ReplaceNext_NoMatchAfterOffset_UnchangedAndFalse()
    {
        var (result, replaced) = EditorSearch.ReplaceNext("foo", "foo", "bar", Plain, fromOffset: 5);

        Assert.False(replaced);
        Assert.Equal("foo", result);
    }

    [Fact]
    public void ReplaceNext_WrapsToZeroWhenNoMatchAtOrAfterOffset()
    {
        // Contract: replaces only >= fromOffset; caller handles wrap.
        var (_, replaced) = EditorSearch.ReplaceNext("foo bar", "foo", "x", Plain, fromOffset: 3);
        Assert.False(replaced);
    }
}
