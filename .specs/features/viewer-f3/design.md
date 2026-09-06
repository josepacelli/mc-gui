# Viewer (F3) Design

## Architecture Overview

The Viewer feature adds a file viewer window accessible via F3 key and `File > View` menu. It follows the existing mc-gui architecture:

- **Core** (`McGui.Core`): Models, interfaces, ViewModel logic
- **Infrastructure** (`McGui.Infrastructure.macOS`): File reading via `IFileSystemService`
- **App** (`McGui.App`): Avalonia UI (Window, ViewModels, Views, KeyBindings)

## Components

### 1. Core Models (`McGui.Core/Models/`)

**ViewerMode** - Enum for viewer display modes
```csharp
public enum ViewerMode
{
    Text,
    Hex
}
```

**ViewerState** - Tracks viewer state for potential persistence
```csharp
public sealed record ViewerState(
    string FilePath,
    ViewerMode Mode,
    long ScrollOffset,
    bool WordWrap,
    string? SearchQuery,
    long SearchMatchIndex
);
```

### 2. Core Services (`McGui.Core/Services/`)

**IViewerService** - Interface for file viewing operations
```csharp
public interface IViewerService
{
    Task<ViewerContent> LoadFileAsync(string filePath, CancellationToken ct);
    Task<ViewerContent> LoadFileChunkAsync(string filePath, long offset, int length, CancellationToken ct);
    long GetFileSize(string filePath);
}
```

**ViewerContent** - Result of file loading
```csharp
public sealed record ViewerContent(
    string Text,           // For text mode
    byte[]? Bytes,         // For hex mode
    long FileSize,
    string Encoding,
    bool IsBinary
);
```

### 3. Infrastructure (`McGui.Infrastructure.macOS/`)

**MacViewerService** - Implements `IViewerService`
- Uses `File.OpenRead` + `StreamReader` for text
- Detects binary via null bytes in first 8KB
- UTF-8 with Latin-1 fallback
- Chunked reading for large files (>10MB)

### 4. App ViewModels (`McGui.App/ViewModels/`)

**ViewerViewModel** - Main viewer logic
- Properties: `FilePath`, `Mode`, `WordWrap`, `Content` (string/hex lines), `SearchQuery`, `Matches`, `CurrentMatchIndex`
- Commands: `ToggleHexCommand`, `ToggleWrapCommand`, `SearchCommand`, `NextMatchCommand`, `PreviousMatchCommand`, `ReloadCommand`, `CloseCommand`
- Keyboard handling: F2/F4/F5/F7/F10, arrows, PgUp/PgDn, Home/End, Ctrl+F

**ViewerWindowViewModel** - Window-level (if separate from ViewerViewModel)

### 5. App Views (`McGui.App/Views/`)

**ViewerWindow.axaml** - Main viewer window
- `Window` (not `Dialog`) for full-screen capability
- Toolbar: F1-F10 buttons (Help, Hex/Ascii, Save, Search, ..., Quit)
- Content area: `ScrollViewer` + `TextBlock` (text) or `ItemsControl` (hex lines)
- Search bar: Collapsible `TextBox` + match counter + navigation buttons
- Status bar: File path, mode, position, encoding

**HexLineView.axaml** - Template for hex display lines
- Monospace font
- Columns: Offset (8 hex), 16 byte pairs, ASCII (16 chars)

### 6. Key Bindings (`McGui.App/Input/`)

Extend `KeyGestureMap` with Viewer-specific actions:
- `GestureAction.ViewerToggleHex` (F4)
- `GestureAction.ViewerToggleWrap` (F2)
- `GestureAction.ViewerSearch` (Ctrl+F)
- `GestureAction.ViewerNextMatch` (F3/Enter)
- `GestureAction.ViewerPrevMatch` (Shift+F3/Shift+Enter)
- `GestureAction.ViewerReload` (F5)
- `GestureAction.ViewerClose` (Esc, F10)

### 7. Menu Integration

**McMenuDefinitions** - Enable `File > View`:
- Add `View` command to File menu (enabled)
- `View file...` remains disabled (future)

### 8. Panel Integration

**PanelViewModel** - Handle F3 key:
- `RequestViewCommand` → opens ViewerWindow for selected file
- Only for files (not directories)
- Passes `FileEntry` to ViewerViewModel

## Data Flow

```
User presses F3 on file
    → PanelViewModel.RequestViewCommand.Execute(fileEntry)
    → ViewerViewModel.LoadFileAsync(filePath)
    → IFileSystemService (MacFileSystemService) reads file
    → ViewerContent returned (text or bytes)
    → ViewerViewModel parses into display lines
    → ViewerWindow.Show()
    → User interacts (scroll, search, toggle hex)
```

## Hex Mode Rendering

For hex display, convert bytes to lines:
```
Offset (8 hex) | 16 byte pairs (2 hex each) | ASCII (16 chars)
00000000       48 65 6C 6C 6F 20 57 6F  72 6C 64 0A 00 00 00 00  Hello World....
00000010       00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  ................
```

Virtualized via `ItemsControl` with `VirtualizingStackPanel` for large files.

## Search Implementation

- Text mode: `TextBlock` with `Inlines` highlighting (Regex matches → `Run` with background)
- Hex mode: Highlight matching byte positions in hex/ASCII columns
- Incremental: Debounced (300ms) on `SearchQuery` change
- Navigation: Maintain `List<int>` of match line indices

## Large File Handling

- Files < 10MB: Load fully into memory
- Files ≥ 10MB: Load first chunk (1MB), show "Loading..." indicator
- Background loading of subsequent chunks on scroll (virtualization)
- Cancel loading on window close

## Testing Strategy

**Unit Tests** (`McGui.Core.Tests`, `McGui.Infrastructure.macOS.Tests`):
- `MacViewerServiceTests`: Load text, binary, large files, encoding fallback
- `ViewerViewModelTests`: Mode toggle, wrap toggle, search, navigation, hex rendering

**Integration Tests** (`McGui.App.Tests`):
- `ViewerWindowTests`: XAML structure, toolbar buttons, key bindings
- `PanelViewerIntegrationTests`: F3 opens viewer for file, not directory

**UAT**: Manual verification of all acceptance criteria

## Dependencies

- **Existing**: `IFileSystemService`, `MacFileSystemService`, `KeyGestureMap`, `McMenuDefinitions`, theming
- **New**: `IViewerService`, `MacViewerService`, `ViewerViewModel`, `ViewerWindow`

## Rollout Plan

1. **Phase 1**: Core models + `IViewerService` + `MacViewerService` + tests
2. **Phase 2**: `ViewerViewModel` + `ViewerWindow` (text mode, wrap, scroll, keyboard)
3. **Phase 3**: Hex mode + toggle + navigation
4. **Phase 4**: Search (Ctrl+F, highlights, navigation)
5. **Phase 5**: Toolbar F-keys + menu integration + mouse interactions
6. **Phase 6**: Edge cases (large files, encoding, empty, binary, reload)

Each phase = 1-2 tasks, atomic commits, tests first.