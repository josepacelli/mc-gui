using System.Text.RegularExpressions;
using McGui.Core.Models;

namespace McGui.Core.Services;

/// <summary>
/// Marking rules for a panel's multi-selection: toggle, pattern-based mark/unmark,
/// and invert (DPC-09 to DPC-13). Mutates the given <see cref="PanelState"/> in place
/// (its <see cref="PanelState.MarkedPaths"/> is a get-only set) and returns it for chaining.
/// </summary>
public static class SelectionService
{
    /// <summary>
    /// DPC-09: toggles the marked state of the entry at <paramref name="index"/> and moves
    /// the cursor to the next entry, clamped to the last entry (no wrap).
    /// </summary>
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

    /// <summary>DPC-10: marks every entry whose name matches the glob <paramref name="pattern"/>.</summary>
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

    /// <summary>DPC-11: unmarks every entry whose name matches the glob <paramref name="pattern"/>.</summary>
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

    /// <summary>DPC-12: inverts the marked state of every entry in the panel.</summary>
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

    // Glob support: "*" matches any sequence, "?" matches a single character, case-sensitive.
    // Spec-precision gap: spec.md does not define case sensitivity for +/- glob patterns
    // (unlike the case-insensitive filter in DPC-33); case-sensitive matching is the simplest default.
    private static Regex GlobToRegex(string pattern)
    {
        var escaped = Regex.Escape(pattern).Replace("\\*", ".*").Replace("\\?", ".");
        return new Regex($"^{escaped}$", RegexOptions.CultureInvariant);
    }
}
