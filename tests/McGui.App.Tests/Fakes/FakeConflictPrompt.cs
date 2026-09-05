using McGui.App.ViewModels;
using McGui.Core.Models;

namespace McGui.App.Tests.Fakes;

public sealed class FakeConflictPrompt : IConflictPrompt
{
    private readonly Queue<ConflictPromptResult> _responses;

    public FakeConflictPrompt(params ConflictPromptResult[] responses)
    {
        _responses = new Queue<ConflictPromptResult>(responses);
    }

    public List<string> PromptedPaths { get; } = [];

    public Task<ConflictPromptResult> PromptAsync(string destinationPath)
    {
        PromptedPaths.Add(destinationPath);
        var response = _responses.Count > 0 ? _responses.Dequeue() : new ConflictPromptResult(FileConflictResolution.Abort, false);
        return Task.FromResult(response);
    }
}
