# Viewer (F3) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/viewer-f3/design.md`
**Status**: Approved

---

## Test Coverage Matrix

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Core models (`ViewerMode`, `ViewerState`, `ViewerContent`) | unit | 1:1 to spec ACs | `tests/McGui.Core.Tests/Models/*Tests.cs` | `dotnet test tests/McGui.Core.Tests` |
| Infrastructure (`MacViewerService`) | unit (real file I/O) | Every spec AC + edge case | `tests/McGui.Infrastructure.macOS.Tests/*Viewer*Tests.cs` | `dotnet test tests/McGui.Infrastructure.macOS.Tests` |
| App ViewModel (`ViewerViewModel`) | unit | 1:1 to spec AC per property/command | `tests/McGui.App.Tests/ViewModels/ViewerViewModelTests.cs` | `dotnet test tests/McGui.App.Tests` |
| App XAML (`ViewerWindow.axaml`) | unit (text/regex) | Every spec AC about markup | `tests/McGui.App.Tests/ViewerWindowStructureTests.cs` | `dotnet test tests/McGui.App.Tests` |
| Key bindings | unit | F2/F4/F5/F7/F10/arrows/PgUp/PgDn/Home/End/Ctrl+F/Esc mapped | `tests/McGui.App.Tests/Input/KeyGestureMapTests.cs` | `dotnet test tests/McGui.App.Tests` |
| Menu integration | unit | `File > View` enabled, `View file...` disabled | `tests/McGui.App.Tests/McMenuDefinitionsTests.cs` | `dotnet test tests/McGui.App.Tests` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After a task touching only one test project | `dotnet test tests/<ProjectName>` |
| Full | After phase completion, or a task touching more than one project | `dotnet build McGui.sln && dotnet test McGui.sln` |
| Build | Config/markup-only task with no new test | `dotnet build McGui.sln -warnaserror` |

---

## Execution Plan

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6

Phase 1:  T1 → T2
Phase 2:  T2 → T3
Phase 3:  T3 → T4
         T3 → T5
Phase 4:  T4 → T5
         T4 → T6
Phase 5:  T5 → T6
Phase 6:  T6 → T7
         T1 → T7
```

---

## Task Breakdown

### T1: Core models for Viewer

**What**: Add `ViewerMode`, `ViewerState`, `ViewerContent` records in `McGui.Core/Models/`
**Where**: `src/McGui.Core/Models/ViewerMode.cs`, `ViewerState.cs`, `ViewerContent.cs` (new files)
**Depends on**: None
**Reuses**: Existing `sealed record` pattern from `CopyMoveOptions`, `OperationProgress`
**Requirement**: VWR-01..19 (all - foundational)

**Done when**:
- [ ] `ViewerMode` enum with `Text`, `Hex`
- [ ] `ViewerState` record with `FilePath`, `Mode`, `ScrollOffset`, `WordWrap`, `SearchQuery`, `SearchMatchIndex`
- [ ] `ViewerContent` record with `Text`, `Bytes`, `FileSize`, `Encoding`, `IsBinary`
- [ ] `dotnet build McGui.sln` succeeds
- [ ] Unit tests for each model (construction, equality)

**Tests**: unit (3 new test files, ~10 facts total)
**Gate**: quick (Core only)

**Commit**: `feat(core): add Viewer models (ViewerMode, ViewerState, ViewerContent)`

---

### T2: IViewerService + MacViewerService

**What**: Create `IViewerService` interface in Core, implement `MacViewerService` in Infrastructure.macOS
**Where**: 
- `src/McGui.Core/Interfaces/IViewerService.cs` (new)
- `src/McGui.Infrastructure.macOS/MacViewerService.cs` (new)
- Update `CompositionRoot.cs` to register `IViewerService`
**Depends on**: T1
**Reuses**: `IFileSystemService` pattern, `MacFileSystemService` for file access
**Requirement**: VWR-01 (load file), VWR-02 (scroll), VWR-44 (encoding), VWR-45 (large files)

**Done when**:
- [ ] `IViewerService` with `LoadFileAsync`, `LoadFileChunkAsync`, `GetFileSize`
- [ ] `MacViewerService` implements interface:
  - Text mode: `StreamReader` UTF-8 → Latin-1 fallback, detect binary (null byte in first 8KB)
  - Hex mode: Read bytes, return `ViewerContent` with `Bytes`
  - Chunked loading for files > 10MB (first 1MB + async rest)
  - `GetFileSize` via `FileInfo.Length`
- [ ] `CompositionRoot` registers `IViewerService` → `MacViewerService`
- [ ] `dotnet build McGui.sln` succeeds
- [ ] Tests: text file loads correctly, binary detected, UTF-8/Latin-1, large file chunking, file size

**Tests**: unit (Infrastructure, real temp-dir I/O, ~8 facts)
**Gate**: quick (Infrastructure only)

**Commit**: `feat(infra): add IViewerService and MacViewerService with text/hex/chunked loading`

---

### T3: ViewerViewModel (text mode, wrap, scroll, keyboard)

**What**: Implement `ViewerViewModel` with text mode, word wrap toggle, scroll, keyboard navigation
**Where**: 
- `src/McGui.App/ViewModels/ViewerViewModel.cs` (new)
- `tests/McGui.App.Tests/ViewModels/ViewerViewModelTests.cs` (new)
**Depends on**: T2
**Reuses**: `ObservableObject`, `RelayCommand`, `IViewerService`, existing `KeyGestureMap` pattern
**Requirement**: VWR-01..04 (text, wrap, scroll, close), VWR-16..19 (keyboard nav)

**Done when**:
- [ ] `ViewerViewModel` properties: `FilePath`, `Mode` (ViewerMode), `WordWrap`, `Content` (string), `Lines` (string[]), `ScrollOffset`, `Title`
- [ ] `LoadAsync(string filePath)` calls `IViewerService.LoadFileAsync`, splits into `Lines`, sets `Content`
- [ ] `ToggleWrapCommand` flips `WordWrap`, notifies UI
- [ ] `CloseCommand` closes window, returns focus to panel
- [ ] Keyboard: Up/Down (line scroll), PgUp/PgDn (page scroll), Home/End (top/bottom), Esc/F10 (close)
- [ ] `dotnet build McGui.sln` succeeds
- [ ] Tests: load text file, wrap toggle, scroll position, keyboard nav, close returns focus

**Tests**: unit (ViewModel, ~12 facts)
**Gate**: quick (App only)

**Commit**: `feat(app): add ViewerViewModel with text mode, wrap, scroll, keyboard nav`

---

### T4: ViewerWindow (text mode UI, toolbar, search bar)

**What**: Create `ViewerWindow.axaml` + `ViewerWindow.axaml.cs` with toolbar, content area, search bar
**Where**: 
- `src/McGui.App/Views/ViewerWindow.axaml` (new)
- `src/McGui.App/Views/ViewerWindow.axaml.cs` (new)
- `tests/McGui.App.Tests/ViewerWindowStructureTests.cs` (new)
**Depends on**: T3
**Reuses**: Avalonia `Window`, `ScrollViewer`, `TextBlock`, theming (`DynamicResource`), `KeyGestureMap`
**Requirement**: VWR-01..04 (UI), VWR-13..15 (toolbar F1-F10), VWR-09..12 (search UI)

**Done when**:
- [ ] `ViewerWindow` is a `Window` (not Dialog), `SizeToContent="WidthAndHeight"`, `MinWidth=800`, `MinHeight=600`
- [ ] Toolbar: 10 buttons F1-F10 with labels: `Help`, `Hex/Ascii`, `Save`, `Search`, `...`, `Quit` (F10)
- [ ] Content: `ScrollViewer` → `TextBlock` (bind `Content`, `TextWrapping` from `WordWrap`)
- [ ] Search bar: Collapsible, `TextBox` (bind `SearchQuery`), match counter, Prev/Next/Close buttons
- [ ] Status bar: File path, mode, line/byte position, encoding
- [ ] XAML structure tests: toolbar buttons present, search bar binds, content area scrolls
- [ ] `dotnet build McGui.sln` succeeds
- [ ] Theming: colors via `DynamicResource` (Light/Dark)

**Tests**: unit (XAML structure, ~8 facts) + build gate
**Gate**: quick (App only)

**Commit**: `feat(app): add ViewerWindow with toolbar, text content, search bar, status bar`

---

### T5: Hex mode + toggle

**What**: Add hex mode rendering, F4 toggle, hex navigation
**Where**: 
- Modify `ViewerViewModel` (add `HexLines`, `HexMode` logic)
- Modify `ViewerWindow.axaml` (hex/content switcher)
- Add `HexLineView.axaml` (template for hex lines)
**Depends on**: T3, T4
**Reuses**: Monospace font from theme, `ItemsControl` virtualization
**Requirement**: VWR-05..08 (hex mode, toggle, navigation)

**Done when**:
- [ ] `ViewerViewModel.Mode` toggles via `ToggleHexCommand` (F4) and toolbar button
- [ ] Text mode: `TextBlock` with `Content`; Hex mode: `ItemsControl` with `HexLines` (array of `HexLine`)
- [ ] `HexLine` record: `Offset`, `Bytes` (byte[16]), `Ascii` (string)
- [ ] Hex rendering: 8-digit offset, 16 byte pairs (2 hex each, space separated), ASCII (printable or `.`)
- [ ] Monospace font via `FontFamily="Monospace"` or theme resource
- [ ] Hex navigation: Up/Down = line (16 bytes), PgUp/PgDn = page, Left/Right = column offset
- [ ] F4 toggles back to text mode at corresponding position
- [ ] `dotnet build McGui.sln` succeeds
- [ ] Tests: hex toggle, hex line rendering, hex navigation, position sync text↔hex

**Tests**: unit (ViewModel hex logic, ~10 facts) + XAML structure
**Gate**: quick (App only)

**Commit**: `feat(app): add hex mode rendering and F4 toggle with navigation`

---

### T6: Incremental search (Ctrl+F, highlights, navigation)

**What**: Implement search bar, highlighting, match navigation
**Where**: 
- Modify `ViewerViewModel` (add `SearchQuery`, `Matches`, `CurrentMatchIndex`, `SearchCommand`, `NextMatchCommand`, `PreviousMatchCommand`)
- Modify `ViewerWindow.axaml` (search bar bindings, highlight rendering)
**Depends on**: T4, T5
**Reuses**: `TextBlock.Inlines` for highlights, debounced search (300ms)
**Requirement**: VWR-09..12 (search open, highlights, next/prev, close)

**Done when**:
- [ ] `SearchCommand` (Ctrl+F) shows search bar, focuses `TextBox`
- [ ] `SearchQuery` debounced (300ms) → computes `Matches` (line indices with match)
- [ ] Highlights: Text mode → `TextBlock.Inlines` with `Run` background; Hex mode → highlight byte positions
- [ ] `NextMatchCommand` (Enter/F3) jumps to next match, updates `CurrentMatchIndex`, scrolls into view
- [ ] `PreviousMatchCommand` (Shift+F3) jumps to previous match
- [ ] Match counter: "Match X of Y" in search bar
- [ ] Esc in search bar → closes search, clears highlights, `SearchQuery` = ""
- [ ] `dotnet build McGui.sln` succeeds
- [ ] Tests: search open, incremental highlights, next/prev navigation, match counter, esc closes

**Tests**: unit (ViewModel search, ~10 facts) + XAML structure
**Gate**: quick (App only)

**Commit**: `feat(app): add incremental search with highlights and match navigation`

---

### T7: Menu integration, mouse, edge cases, polish

**What**: Enable `File > View` menu, mouse interactions, edge cases (empty, binary, large, reload, encoding)
**Where**: 
- `McMenuDefinitions` enable `File > View`
- `PanelViewModel` F3 handling (directories do nothing)
- `ViewerViewModel` edge cases
- Update `KeyGestureMap` with Viewer actions
**Depends on**: T1-T6
**Reuses**: Existing menu/keybinding patterns
**Requirement**: VWR-13 (menu), VWR-16..19 (mouse), VWR-41..46 (edge cases)

**Done when**:
- [ ] `McMenuDefinitions`: `File > View` enabled, command = `RequestViewCommand`; `View file...` disabled
- [ ] `PanelViewModel.RequestViewCommand` opens `ViewerWindow` for selected file (not directory)
- [ ] `KeyGestureMap`: F3=View, F2=Wrap, F4=Hex, F5=Reload, F7=Search, F10=Close, arrows/PgUp/PgDn/Home/End, Ctrl+F
- [ ] Mouse: wheel scrolls, click positions caret, drag selects, Ctrl+C copies selection
- [ ] Edge cases: 
  - Empty file → "Empty file" placeholder
  - Binary file → auto-switch to hex mode with notice
  - Large file (>10MB) → chunked loading + indicator
  - Invalid UTF-8 → replacement chars (�)
  - F5 reloads file, preserves mode/position
  - External file change → notification + reload offer
- [ ] `dotnet build McGui.sln -warnaserror` succeeds
- [ ] `dotnet test McGui.sln` passes (all 236+ new tests)
- [ ] Tests: menu enabled, F3 opens viewer, mouse interactions, edge cases covered

**Tests**: unit (menu, keybindings, mouse, edge cases ~15 facts) + full suite
**Gate**: full

**Commit**: `feat(app): integrate Viewer with menu, keybindings, mouse, edge cases`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6

Phase 1:  T1 → T2
Phase 2:  T2 → T3
Phase 3:  T3 → T4
Phase 4:  T4 → T5
Phase 5:  T5 → T6
Phase 6:  T6 → T7
```

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: Core models | 3 new files, 1 concern | ✅ Granular |
| T2: IViewerService + impl | 1 interface + 1 impl + DI | ✅ Granular |
| T3: ViewerViewModel (text) | 1 ViewModel, 1 concern | ✅ Granular |
| T4: ViewerWindow (UI) | 1 Window + XAML, cohesive | ✅ Granular |
| T5: Hex mode | Extends ViewModel/View, 1 concern | ✅ Granular |
| T6: Search | Extends ViewModel/View, 1 concern | ✅ Granular |
| T7: Integration/polish | Menu, keys, mouse, edge cases | ⚠️ OK - cross-cutting but final phase |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | None | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T2 | T2 → T3 | ✅ Match |
| T4 | T3 | T3 → T4 | ✅ Match |
| T5 | T3, T4 | T3 → T5, T4 → T5 | ✅ Match |
| T6 | T4, T5 | T4 → T6, T5 → T6 | ✅ Match |
| T7 | T1-T6 | T6 → T7 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: Core models | Core models | unit | unit | ✅ OK |
| T2: IViewerService + impl | Infrastructure file ops | unit | unit | ✅ OK |
| T3: ViewerViewModel (text) | App ViewModel | unit | unit | ✅ OK |
| T4: ViewerWindow (UI) | App XAML | unit (text/regex) | unit | ✅ OK |
| T5: Hex mode | App ViewModel + XAML | unit | unit | ✅ OK |
| T6: Search | App ViewModel + XAML | unit | unit | ✅ OK |
| T7: Integration | App (menu, keys, mouse) | unit | unit | ✅ OK |

---

## Tips

- **Re-read spec.md/design.md before Execute** - this file was authored ahead of implementation
- **Large file handling**: Use `FileStream` + `StreamReader` with buffer; cancel on window close via `CancellationToken`
- **Hex rendering**: Pre-compute `HexLine[]` on mode switch; virtualize via `ItemsControl` + `VirtualizingStackPanel`
- **Search highlights**: Use `TextBlock.Inlines.Clear()` + add `Run` elements for matches; clear on search close
- **Keyboard**: Add Viewer actions to `KeyGestureMap`; `ViewerWindow` handles `KeyDown` for focus-aware keys
- **One commit per task** - Conventional Commits, validated via `check_commit.py`
- **Full suite before T7** - touches multiple projects

---

## Task Verification Standards

Every task MUST follow the `Done when` + `Tests` + `Gate` fields defined above. Each `Done when` entry must be specific, testable (binary pass/fail), and reference the gate check command. Include the expected test count to prevent silent deletions.