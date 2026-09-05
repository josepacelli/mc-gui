using System;
using McGui.App.ViewModels;
using McGui.Core.Interfaces;
using McGui.Infrastructure.macOS;
using Microsoft.Extensions.DependencyInjection;

namespace McGui.App;

public static class CompositionRoot
{
    public static IServiceProvider BuildServiceProvider()
    {
        var services = new ServiceCollection();

        services.AddSingleton<IFileSystemService, MacFileSystemService>();
        services.AddSingleton<ITrashService, MacTrashService>();
        services.AddSingleton<IPathHistoryStore, MacPathHistoryStore>();
        services.AddTransient<MainWindowViewModel>();

        return services.BuildServiceProvider();
    }
}
