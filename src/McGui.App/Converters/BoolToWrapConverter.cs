using System;
using Avalonia.Data.Converters;
using Avalonia.Media;

namespace McGui.App.Converters;

public class BoolToWrapConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, System.Globalization.CultureInfo culture)
    {
        if (value is bool wrap)
        {
            return wrap ? TextWrapping.Wrap : TextWrapping.NoWrap;
        }
        return TextWrapping.Wrap;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, System.Globalization.CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}