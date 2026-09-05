using System;
using System.Globalization;

namespace McGui.App;

public static class FileSizeFormatter
{
    private static readonly string[] Units = ["B", "kB", "MB", "GB", "TB"];

    public static string Format(long bytes)
    {
        if (bytes < 1024)
        {
            return bytes + " B";
        }

        var value = (double)bytes;
        var unitIndex = 0;
        while (value >= 1024 && unitIndex < Units.Length - 1)
        {
            value /= 1024;
            unitIndex++;
        }

        return value.ToString(unitIndex == 0 ? "0" : "0.#", CultureInfo.InvariantCulture) + " " + Units[unitIndex];
    }
}
