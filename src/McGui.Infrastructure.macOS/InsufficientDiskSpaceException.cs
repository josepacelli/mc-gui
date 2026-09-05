namespace McGui.Infrastructure.macOS;

public sealed class InsufficientDiskSpaceException(long requiredBytes, long availableBytes)
    : Exception($"Insufficient disk space: required {requiredBytes} bytes, available {availableBytes} bytes.")
{
    public long RequiredBytes { get; } = requiredBytes;

    public long AvailableBytes { get; } = availableBytes;
}
