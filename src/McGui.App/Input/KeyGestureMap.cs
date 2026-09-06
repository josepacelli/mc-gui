using System.Collections.Generic;
using Avalonia.Input;

namespace McGui.App.Input;

public static class KeyGestureMap
{
    public static readonly IReadOnlyDictionary<KeyGesture, GestureAction> Gestures = new Dictionary<KeyGesture, GestureAction>
    {
        [new KeyGesture(Key.F1)] = GestureAction.Help,
        [new KeyGesture(Key.F2)] = GestureAction.UserMenu,
        [new KeyGesture(Key.F3)] = GestureAction.View,
        [new KeyGesture(Key.F4)] = GestureAction.Edit,
        [new KeyGesture(Key.F5)] = GestureAction.Copy,
        [new KeyGesture(Key.F6)] = GestureAction.Move,
        [new KeyGesture(Key.F7)] = GestureAction.MakeDirectory,
        [new KeyGesture(Key.F8)] = GestureAction.Delete,
        [new KeyGesture(Key.F9)] = GestureAction.PullDownMenu,
        [new KeyGesture(Key.F10)] = GestureAction.Quit,
        [new KeyGesture(Key.Tab)] = GestureAction.SwitchActivePanel,
        [new KeyGesture(Key.Insert)] = GestureAction.ToggleMark,
        [new KeyGesture(Key.Add)] = GestureAction.MarkByPattern,
        [new KeyGesture(Key.Subtract)] = GestureAction.UnmarkByPattern,
        [new KeyGesture(Key.Multiply)] = GestureAction.InvertMarks,
        [new KeyGesture(Key.R, KeyModifiers.Control)] = GestureAction.RefreshPanel,
        [new KeyGesture(Key.H, KeyModifiers.Control)] = GestureAction.ToggleHiddenEntries,
        [new KeyGesture(Key.Back)] = GestureAction.NavigateToParent,
        [new KeyGesture(Key.F12)] = GestureAction.CycleTheme,
    };

    public static readonly IReadOnlySet<GestureAction> DisabledActions = new HashSet<GestureAction>
    {
        GestureAction.Help,
        GestureAction.UserMenu,
        GestureAction.View,
        GestureAction.Edit,
    };
}
