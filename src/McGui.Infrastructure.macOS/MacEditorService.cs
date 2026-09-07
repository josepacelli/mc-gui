using McGui.Core.Interfaces;
using McGui.Core.Models;

namespace McGui.Infrastructure.macOS;

public sealed class MacEditorService : IEditorService
{
    private const long LargeFileThreshold = 50 * 1024 * 1024; // 50MB

    private static readonly System.Text.Encoding Utf8Strict = System.Text.Encoding.GetEncoding(
        "UTF-8",
        new System.Text.EncoderExceptionFallback(),
        new System.Text.DecoderExceptionFallback());

    private static readonly byte[] Utf8Bom = [0xEF, 0xBB, 0xBF];

    public async Task<EditorDocumentState> LoadAsync(string filePath, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();

        var fileInfo = new FileInfo(filePath);
        var isLarge = fileInfo.Length > LargeFileThreshold;
        var isReadOnly = IsReadOnly(filePath);

        if (fileInfo.Length == 0)
        {
            return new EditorDocumentState(filePath, string.Empty, "UTF-8", isReadOnly, isLarge);
        }

        var bytes = await File.ReadAllBytesAsync(filePath, ct);

        // BOM-aware UTF-8: strip BOM, remember it so save can re-emit.
        string encoding = "UTF-8";
        int start = 0;
        if (HasBom(bytes))
        {
            start = Utf8Bom.Length;
            encoding = "UTF-8 BOM";
        }

        string text;
        if (start > 0 || IsValidUtf8(bytes, start))
        {
            text = System.Text.Encoding.UTF8.GetString(bytes, start, bytes.Length - start);
        }
        else
        {
            text = System.Text.Encoding.Latin1.GetString(bytes);
            encoding = "Latin-1";
        }

        return new EditorDocumentState(filePath, text, encoding, isReadOnly, isLarge);
    }

    public async Task SaveAsync(string filePath, string text, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        await File.WriteAllTextAsync(filePath, text, new System.Text.UTF8Encoding(encoderShouldEmitUTF8Identifier: false), ct);
    }

    public bool IsReadOnly(string filePath)
    {
        try
        {
            var mode = File.GetUnixFileMode(filePath);
            const UnixFileMode writeBits = UnixFileMode.UserWrite | UnixFileMode.GroupWrite | UnixFileMode.OtherWrite;
            return (mode & writeBits) == 0;
        }
        catch (IOException)
        {
            return true;
        }
        catch (UnauthorizedAccessException)
        {
            return true;
        }
    }

    private static bool HasBom(byte[] bytes) =>
        bytes.Length >= Utf8Bom.Length
        && bytes[0] == Utf8Bom[0]
        && bytes[1] == Utf8Bom[1]
        && bytes[2] == Utf8Bom[2];

    private static bool IsValidUtf8(byte[] bytes, int start)
    {
        try
        {
            Utf8Strict.GetCharCount(bytes, start, bytes.Length - start);
            return true;
        }
        catch (System.Text.DecoderFallbackException)
        {
            return false;
        }
    }
}