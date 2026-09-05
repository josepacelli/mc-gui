using System.Text.RegularExpressions;
using McGui.Core.Models;

namespace McGui.Core.Services;

public static class SelectionService
{
    public static PanelState Toggle(PanelState state, int index)
    {
        if (index < 0 || index >= state.Entries.Count)
        {
            return state;
        }

        var path = state.Entries[index].FullPath;
        if (!state.MarkedPaths.Remove(path))
        {
            state.MarkedPaths.Add(path);
        }

        state.CursorIndex = Math.Min(index + 1, state.Entries.Count - 1);
        return state;
    }

    public static PanelState MarkByPattern(PanelState state, string pattern)
    {
        var regex = GlobToRegex(pattern);
        foreach (var entry in state.Entries)
        {
            if (regex.IsMatch(entry.Name))
            {
                state.MarkedPaths.Add(entry.FullPath);
            }
        }

        return state;
    }

    public static PanelState UnmarkByPattern(PanelState state, string pattern)
    {
        var regex = GlobToRegex(pattern);
        foreach (var entry in state.Entries)
        {
            if (regex.IsMatch(entry.Name))
            {
                state.MarkedPaths.Remove(entry.FullPath);
            }
        }

        return state;
    }

    public static PanelState Invert(PanelState state)
    {
        foreach (var entry in state.Entries)
        {
            if (!state.MarkedPaths.Remove(entry.FullPath))
            {
                state.MarkedPaths.Add(entry.FullPath);
            }
        }

        return state;
    }

    private static Regex GlobToRegex(string pattern)
    {
        var escaped = Regex.Escape(pattern).Replace("\\*", ".*").Replace("\\?", ".");
        return new Regex($"^{escaped}$", RegexOptions.CultureInvariant);
    }
}
