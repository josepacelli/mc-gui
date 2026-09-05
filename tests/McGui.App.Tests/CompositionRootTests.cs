using McGui.App;
using McGui.App.ViewModels;
using McGui.Core.Interfaces;
using McGui.Infrastructure.macOS;
using Microsoft.Extensions.DependencyInjection;

namespace McGui.App.Tests;

public class CompositionRootTests
{
    [Fact]
    public void BuildServiceProvider_ResolvesAllRegisteredServicesWithoutException()
    {
        var provider = CompositionRoot.BuildServiceProvider();

        var fileSystemService = provider.GetRequiredService<IFileSystemService>();
        var trashService = provider.GetRequiredService<ITrashService>();
        var pathHistoryStore = provider.GetRequiredService<IPathHistoryStore>();
        var mainWindowViewModel = provider.GetRequiredService<MainWindowViewModel>();

        Assert.IsType<MacFileSystemService>(fileSystemService);
        Assert.IsType<MacTrashService>(trashService);
        Assert.IsType<MacPathHistoryStore>(pathHistoryStore);
        Assert.NotNull(mainWindowViewModel);
    }
}
