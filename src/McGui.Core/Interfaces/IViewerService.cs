using McGui.Core.Models;

namespace McGui.Core.Interfaces;

public interface IViewerService
{
    Task<ViewerContent> LoadFileAsync(string filePath, CancellationToken ct);

    Task<ViewerContent> LoadFileChunkAsync(string filePath, long offset, int length, CancellationToken ct);

    long GetFileSize(string filePath);
}