using System.Threading.Tasks;

namespace McGui.App.ViewModels;

public enum SaveChangesResult
{
    Save,
    Discard,
    Cancel,
}

public interface ISaveChangesPrompt
{
    Task<SaveChangesResult> PromptAsync(string fileName);
}