namespace McGui.Infrastructure.macOS;

internal static class VolumeLocator
{
    public static DriveInfo FindDrive(string path)
    {
        var fullPath = Path.GetFullPath(path);
        return DriveInfo.GetDrives()
            .Where(drive => fullPath.StartsWith(drive.RootDirectory.FullName, StringComparison.Ordinal))
            .OrderByDescending(drive => drive.RootDirectory.FullName.Length)
            .First();
    }
}
