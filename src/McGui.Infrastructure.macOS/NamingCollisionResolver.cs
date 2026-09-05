namespace McGui.Infrastructure.macOS;

internal static class NamingCollisionResolver
{
    public static string ResolveCollision(string path)
    {
        if (!File.Exists(path) && !Directory.Exists(path))
        {
            return path;
        }

        var directory = Path.GetDirectoryName(path) ?? "";
        var stem = Path.GetFileNameWithoutExtension(path);
        var extension = Path.GetExtension(path);
        for (var counter = 2; ; counter++)
        {
            var candidate = Path.Combine(directory, $"{stem} {counter}{extension}");
            if (!File.Exists(candidate) && !Directory.Exists(candidate))
            {
                return candidate;
            }
        }
    }
}
