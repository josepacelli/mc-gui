namespace McGui.Core.Models;

public sealed record CopyMoveOptions(bool PreserveAttributes, bool FollowSymlinks)
{
    public static readonly CopyMoveOptions Default = new(PreserveAttributes: false, FollowSymlinks: true);
}