using System.Threading.Tasks;
using McGui.Core.Models;

namespace McGui.App.ViewModels;

public interface IConflictPrompt
{
    Task<ConflictPromptResult> PromptAsync(string destinationPath);
}

public sealed record ConflictPromptResult(FileConflictResolution Resolution, bool ApplyToAll);
