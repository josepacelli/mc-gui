using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.App.Tests.Fakes;

public sealed class FakeViewerService : IViewerService
{
    public Task<ViewerContent> LoadFileAsync(string filePath, CancellationToken ct)
    {
        if (!File.Exists(filePath))
        {
            return Task.FromResult(new ViewerContent(string.Empty, null, 0, "UTF-8", false));
        }

        var content = File.ReadAllText(filePath);
        var info = new FileInfo(filePath);
        return Task.FromResult(new ViewerContent(content, null, info.Length, "UTF-8", false));
    }

    public Task<ViewerContent> LoadFileChunkAsync(string filePath, long offset, int length, CancellationToken ct)
    {
        return LoadFileAsync(filePath, CancellationToken.None);
    }

    public long GetFileSize(string filePath)
    {
        try
        {
            return new FileInfo(filePath).Length;
        }
        catch
        {
            return 0;
        }
    }
}