using Avalonia.Input;
using McGui.App.Input;

namespace McGui.App.Tests.Input;

public class KeyGestureMapTests
{
    private static readonly KeyGesture[] RequiredGestures =
    [
        new(Key.F1),
        new(Key.F2),
        new(Key.F3),
        new(Key.F4),
        new(Key.F5),
        new(Key.F6),
        new(Key.F7),
        new(Key.F8),
        new(Key.F9),
        new(Key.F10),
        new(Key.Tab),
        new(Key.Insert),
        new(Key.Add),
        new(Key.Subtract),
        new(Key.Multiply),
        new(Key.R, KeyModifiers.Control),
        new(Key.H, KeyModifiers.Control),
        new(Key.Back),
    ];

    [Fact]
    public void Gestures_CoverEveryKeyRequiredBySpec()
    {
        foreach (var gesture in RequiredGestures)
        {
            Assert.True(KeyGestureMap.Gestures.ContainsKey(gesture), $"Missing gesture: {gesture}");
        }

        Assert.Equal(RequiredGestures.Length, KeyGestureMap.Gestures.Count);
    }

    [Fact]
    public void ViewAndEditActions_AreMarkedDisabled()
    {
        Assert.Contains(GestureAction.View, KeyGestureMap.DisabledActions);
        Assert.Contains(GestureAction.Edit, KeyGestureMap.DisabledActions);
        Assert.Equal(2, KeyGestureMap.DisabledActions.Count);
    }

    [Fact]
    public void F3AndF4_MapToDisabledActions()
    {
        Assert.Equal(GestureAction.View, KeyGestureMap.Gestures[new KeyGesture(Key.F3)]);
        Assert.Equal(GestureAction.Edit, KeyGestureMap.Gestures[new KeyGesture(Key.F4)]);
    }
}
