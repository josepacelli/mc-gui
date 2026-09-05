using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Interactivity;

namespace McGui.App.Views;

public partial class TextPromptDialog : Window
{
    public TextPromptDialog()
    {
        InitializeComponent();
    }

    public string? PromptText { get; private set; }

    private void OnOk(object? sender, RoutedEventArgs e)
    {
        PromptText = InputBox.Text;
        Close();
    }

    private void OnCancel(object? sender, RoutedEventArgs e)
    {
        PromptText = null;
        Close();
    }

    public static async Task<string?> ShowAsync(Window owner, string title, string promptLabel)
    {
        var dialog = new TextPromptDialog { Title = title };
        dialog.PromptLabel.Text = promptLabel;
        await dialog.ShowDialog(owner);
        return dialog.PromptText;
    }
}
