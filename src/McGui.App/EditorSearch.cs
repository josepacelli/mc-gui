using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace McGui.App;

public readonly record struct SearchMatch(int Index, int Length);

public sealed record SearchOptions(bool Regex, bool CaseSensitive, bool WholeWord);

public static class EditorSearch
{
    public static IReadOnlyList<SearchMatch> FindAll(string text, string pattern, SearchOptions options)
    {
        if (string.IsNullOrEmpty(pattern) || text.Length == 0)
        {
            return Array.Empty<SearchMatch>();
        }

        var regex = BuildRegex(pattern, options);
        var matches = new List<SearchMatch>();
        foreach (Match m in regex.Matches(text))
        {
            if (options.WholeWord && !IsWholeWord(text, m.Index, m.Length))
            {
                continue;
            }

            matches.Add(new SearchMatch(m.Index, m.Length));
        }

        return matches;
    }

    public static (string Text, int Count) ReplaceAll(string text, string pattern, string replacement, SearchOptions options)
    {
        if (string.IsNullOrEmpty(pattern))
        {
            return (text, 0);
        }

        var regex = BuildRegex(pattern, options);
        int count = 0;
        var result = regex.Replace(text, m =>
        {
            if (options.WholeWord && !IsWholeWord(text, m.Index, m.Length))
            {
                return m.Value;
            }

            count++;
            return m.Result(replacement);
        });

        return (result, count);
    }

    private static Regex BuildRegex(string pattern, SearchOptions options)
    {
        var regexOptions = RegexOptions.None;
        if (!options.CaseSensitive)
        {
            regexOptions |= RegexOptions.IgnoreCase;
        }

        var expr = options.Regex ? pattern : Regex.Escape(pattern);
        return new Regex(expr, regexOptions);
    }

    private static bool IsWholeWord(string text, int index, int length)
    {
        bool leftOk = index == 0 || !IsWordChar(text[index - 1]);
        bool rightOk = index + length >= text.Length || !IsWordChar(text[index + length]);
        return leftOk && rightOk;
    }

    private static bool IsWordChar(char c) => char.IsLetterOrDigit(c) || c == '_';
}