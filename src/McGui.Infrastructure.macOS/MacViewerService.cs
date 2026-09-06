using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.Infrastructure.macOS;

public sealed class MacViewerService : IViewerService
{
    private const int BinaryDetectionBufferSize = 8192;
    private const long LargeFileThreshold = 10 * 1024 * 1024; // 10MB
    private const int ChunkSize = 1024 * 1024; // 1MB chunks

    public async Task<ViewerContent> LoadFileAsync(string filePath, CancellationToken ct)
    {
        var fileSize = GetFileSize(filePath);

        if (fileSize == 0)
        {
            return new ViewerContent(string.Empty, null, 0, "UTF-8", false);
        }

        if (fileSize > LargeFileThreshold)
        {
            // For large files, load first chunk only
            return await LoadFileChunkAsync(filePath, 0, ChunkSize, ct);
        }

        return await LoadFileChunkAsync(filePath, 0, (int)fileSize, ct);
    }

    public async Task<ViewerContent> LoadFileChunkAsync(string filePath, long offset, int length, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();

        await using var stream = File.OpenRead(filePath);
        stream.Seek(offset, SeekOrigin.Begin);

        var buffer = new byte[length];
        var totalRead = 0;
        while (totalRead < length)
        {
            ct.ThrowIfCancellationRequested();
            var read = await stream.ReadAsync(buffer.AsMemory(totalRead, length - totalRead), ct);
            if (read == 0)
            {
                break;
            }
            totalRead += read;
        }

        if (totalRead == 0)
        {
            return new ViewerContent(string.Empty, null, 0, "UTF-8", false);
        }

        var actualBuffer = totalRead == length ? buffer : buffer[..totalRead];

        // Detect binary: check for null bytes in first 8KB
        var detectionLength = Math.Min(BinaryDetectionBufferSize, actualBuffer.Length);
        var isBinary = false;
        for (var i = 0; i < detectionLength; i++)
        {
            if (actualBuffer[i] == 0)
            {
                isBinary = true;
                break;
            }
        }

        if (isBinary)
        {
            return new ViewerContent(string.Empty, actualBuffer, actualBuffer.Length, "binary", true);
        }

        // Try UTF-8 with strict decoding (throws on invalid sequences)
        string text;
        string encoding;
        var utf8Encoding = System.Text.Encoding.GetEncoding("UTF-8",
            new System.Text.EncoderExceptionFallback(),
            new System.Text.DecoderExceptionFallback());
        try
        {
            text = utf8Encoding.GetString(actualBuffer);
            encoding = "UTF-8";
        }
        catch (System.Text.DecoderFallbackException)
        {
            // Fallback to Latin-1
            text = System.Text.Encoding.Latin1.GetString(actualBuffer);
            encoding = "Latin-1";
        }

        return new ViewerContent(text, null, actualBuffer.Length, encoding, false);
    }

    public long GetFileSize(string filePath)
    {
        try
        {
            var info = new FileInfo(filePath);
            return info.Length;
        }
        catch (FileNotFoundException)
        {
            return 0;
        }
    }
}