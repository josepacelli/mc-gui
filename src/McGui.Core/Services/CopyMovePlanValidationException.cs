namespace McGui.Core.Services;

/// <summary>
/// Thrown by <see cref="CopyMovePlanner"/> when a copy/move request must be rejected
/// before anything is written (circular copy/move, or moving the other panel's
/// current directory). Carries a human-readable explanation for the confirmation dialog.
/// </summary>
public sealed class CopyMovePlanValidationException(string message) : Exception(message)
{
}
