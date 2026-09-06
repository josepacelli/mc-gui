# macOS Native Chrome Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/macos-native-chrome/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase sampling. Guidelines found: none (`AGENTS.md`/`CONTRIBUTING.md` absent) - repo's own existing tests set the floor. This repo has no `Avalonia.Headless` package - no test instantiates a real `Window`/`UserControl`. The established pattern for XAML structure is text/regex assertion against the `.axaml` file content (`McMenuDefinitionsTests.cs`'s `MainWindowMenuBarStructureTests`, `Theming/ThemeResourcesTests.cs`); the established pattern for `Window` code-behind that touches live Avalonia runtime APIs (`OnOpened`/`ApplySystemAccent`) is **no test - build gate only**, since it cannot run outside a real windowing session.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------- | --------------------- | ----------------- | ------------ |
| ViewModel property (plain C#, e.g. `IsMacOS`) | unit | 1:1 to spec AC per platform branch | `tests/McGui.App.Tests/ViewModels/*Tests.cs` | `dotnet test tests/McGui.App.Tests` |
| XAML structure (`NativeMenu`, `Classes`, `Style Selector`) | unit (text/regex on file content) | Every spec AC about markup presence/parity has an assertion | `tests/McGui.App.Tests/*.cs` | `dotnet test tests/McGui.App.Tests` |
| Theme brush tokens | unit (text/regex on file content) | New keys present in both `Light` and `Dark`, valid color value - via existing `ThemeResourcesTests` | `tests/McGui.App.Tests/Theming/ThemeResourcesTests.cs` | `dotnet test tests/McGui.App.Tests` |
| `Window` code-behind touching live Avalonia runtime APIs (`ApplyMacChrome`) | none | build gate only - same precedent as existing `OnOpened`/`ApplySystemAccent` (no headless Avalonia host in this repo) | `src/McGui.App/MainWindow.axaml.cs` | build gate only |

## Gate Check Commands

> Generated from codebase (`McGui.sln`, `dotnet test` already used as sole test runner - no separate lint/format script found in the repo).

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After tasks with unit tests only | `dotnet test tests/McGui.App.Tests` |
| Full | After phase completion, or a task touching more than one project | `dotnet build McGui.sln && dotnet test McGui.sln` |
| Build | Config/markup-only task with no new test (per matrix "none" row) | `dotnet build McGui.sln` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: P1 - Extended title bar with inline traffic lights

```
T1
```

### Phase 2: P2 - Native macOS menu bar

```
T2
```

### Phase 3: P3 - Native finish for file list and F1-F10 bar

```
T3 → T4 → T5 → T6
```

---

## Task Breakdown

### T1: Apply extended client area chrome on macOS only ✅ Done

**What**: Add `ApplyMacChrome()` to `MainWindow.axaml.cs`, called once from `OnOpened` guarded by `OperatingSystem.IsMacOS()`; sets `ExtendClientAreaToDecorationsHint = true` and `WindowDecorations = WindowDecorations.Full`. No change on Windows/Linux (method not called).
**Where**: `src/McGui.App/MainWindow.axaml.cs`
**Depends on**: None
**Reuses**: `OnOpened` (`MainWindow.axaml.cs:29`) - same method that already applies system accent
**Requirement**: MACUI-01, MACUI-02, MACUI-03, MACUI-04

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `ApplyMacChrome()` exists, called from `OnOpened` only when `OperatingSystem.IsMacOS()`
- [ ] Sets `ExtendClientAreaToDecorationsHint = true` and `WindowDecorations = WindowDecorations.Full`
- [ ] `Title` binding/value untouched ("Midnight Commander GUI")
- [ ] `dotnet build McGui.sln` succeeds

**Tests**: none (matrix: `Window` code-behind touching live Avalonia runtime APIs - same precedent as `ApplySystemAccent`)
**Gate**: build

**Commit**: `feat(app): extend client area chrome with inline traffic lights on macOS`

---

### T2: Mirror in-window menu into the native macOS menu bar ✅ Done

**What**: Add `<NativeMenu.Menu>` to `MainWindow.axaml` with a `NativeMenuItem` tree that mirrors every header/item of the existing in-window `Menu` (`_Left`, `_File`, `_Command`, `_Options`, `_Right`), reusing the exact same `Command`/`CommandParameter`/`IsEnabled` bindings. Add a text-based structure test proving parity (headers present in order, every bound item's `Command` matches its in-window counterpart, every `IsEnabled="False"` item mirrored as disabled).
**Where**: `src/McGui.App/MainWindow.axaml` (add), `tests/McGui.App.Tests/MainWindowNativeMenuTests.cs` (new)
**Depends on**: None
**Reuses**: Existing `<Menu x:Name="MainMenu">` block (`MainWindow.axaml:12-115`); test style from `MainWindowMenuBarStructureTests` (`McMenuDefinitionsTests.cs:140-212`)
**Requirement**: MACUI-05, MACUI-06, MACUI-07, MACUI-08, MACUI-09

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `NativeMenu.Menu` headers match `_Left`, `_File`, `_Command`, `_Options`, `_Right` in the same order
- [ ] Every enabled in-window `MenuItem` with a `Command` has a matching `NativeMenuItem` with the same `Command`/`CommandParameter`
- [ ] Every `IsEnabled="False"` in-window item is mirrored as `IsEnabled="False"`
- [ ] In-window `Menu`/F2 `PullDownMenu` behavior unchanged (no code removed from `OpenFirstMenu`/`MainMenu`)
- [ ] Gate check passes: `dotnet test tests/McGui.App.Tests`
- [ ] Test count: existing App.Tests count + new `MainWindowNativeMenuTests` facts, all passing (no silent deletions)

**Tests**: unit (text-based XAML structure)
**Gate**: quick

**Commit**: `feat(app): mirror in-window menu into native macOS menu bar`

---

### T3: Add native brush tokens to Themes.axaml ✅ Done

**What**: Add `NativeListHoverBrush`, `NativeListSelectedBrush`, `NativeToolbarBackgroundBrush`, `NativeToolbarButtonForegroundBrush` `SolidColorBrush` keys to both `Light` and `Dark` dictionaries in `Themes.axaml`. Extend `ThemeResourcesTests.ExpectedTokens` with the four new keys (existing parametrized test already asserts both-theme presence + valid color format for every listed token).
**Where**: `src/McGui.App/Themes.axaml` (modify), `tests/McGui.App.Tests/Theming/ThemeResourcesTests.cs` (modify `ExpectedTokens`)
**Depends on**: None
**Reuses**: `ResourceDictionary.ThemeDictionaries` pattern already used for `PanelBorderBrush` etc. (`Themes.axaml:3-28`)
**Requirement**: MACUI-10, MACUI-11

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Four new brush keys defined in both `Light` and `Dark`
- [ ] `ExpectedTokens` in `ThemeResourcesTests.cs` includes the four new keys
- [ ] Gate check passes: `dotnet test tests/McGui.App.Tests`
- [ ] Test count: existing `ThemeResourcesTests` facts still pass with 4 more tokens covered (no silent deletions)

**Tests**: unit (text-based, reuses existing parametrized test)
**Gate**: quick

**Commit**: `feat(app): add native list/toolbar brush tokens for macOS chrome`

---

### T4: Expose `IsMacOS` on PanelViewModel and MainWindowViewModel ✅ Done

**What**: Add a read-only `bool IsMacOS => OperatingSystem.IsMacOS();` property to `PanelViewModel` and to `MainWindowViewModel`. Pure platform check, no other state.
**Where**: `src/McGui.App/ViewModels/PanelViewModel.cs`, `src/McGui.App/ViewModels/MainWindowViewModel.cs`
**Depends on**: T3
**Reuses**: none new - direct `OperatingSystem.IsMacOS()` call, same BCL API already used in the codebase's `Infrastructure` layer
**Requirement**: MACUI-12, MACUI-13, MACUI-14

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `PanelViewModel.IsMacOS` and `MainWindowViewModel.IsMacOS` both return `OperatingSystem.IsMacOS()`
- [ ] Gate check passes: `dotnet test tests/McGui.App.Tests`
- [ ] Test count: `PanelViewModelTests`/`MainWindowViewModelTests` gain one fact each asserting `IsMacOS == OperatingSystem.IsMacOS()`, all passing (no silent deletions)

**Tests**: unit
**Gate**: quick

**Commit**: `feat(app): expose IsMacOS on panel and main window view models`

---

### T5: Native hover/selection styling on the file list (macOS only) ✅ Done

**What**: In `PanelView.axaml`, bind `Classes.native="{Binding IsMacOS}"` on the file-list `ListBox` (same pattern as the existing `Classes.active="{Binding IsActive}"` on `Border.panelRoot`), and add `Style Selector="ListBox.native ListBoxItem:pointerover"` / `:selected` using `{DynamicResource NativeListHoverBrush}` / `NativeListSelectedBrush`. No zebra-striping (per spec Assumptions). Add a text-based test on `PanelView.axaml` asserting the binding and the two selectors exist.
**Where**: `src/McGui.App/Views/PanelView.axaml` (modify), `tests/McGui.App.Tests/PanelViewNativeStyleTests.cs` (new)
**Depends on**: T4
**Reuses**: `Classes.active="{Binding IsActive}"` pattern and `<UserControl.Styles>` block (`PanelView.axaml:9-20`)
**Requirement**: MACUI-10, MACUI-11, MACUI-13

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `ListBox` has `Classes.native="{Binding IsMacOS}"`
- [ ] `Style Selector="ListBox.native ListBoxItem:pointerover"` uses `NativeListHoverBrush`; `:selected` uses `NativeListSelectedBrush`
- [ ] No `AlternationCount`/zebra-striping added
- [ ] Windows/Linux unaffected (class only applied when `IsMacOS` is true - no unconditional style change)
- [ ] Gate check passes: `dotnet test tests/McGui.App.Tests`
- [ ] Test count: existing App.Tests count + new `PanelViewNativeStyleTests` facts, all passing (no silent deletions)

**Tests**: unit (text-based XAML structure)
**Gate**: quick

**Commit**: `feat(app): style file list hover/selection natively on macOS`

---

### T6: Native toolbar styling on the F1-F10 button bar (macOS only) ✅ Done

**What**: In `MainWindow.axaml`, bind `Classes.fkey="{Binding IsMacOS}"` on each of the ten F1-F10 `Button` elements (Command/CommandParameter/IsEnabled untouched), and add a `<Window.Styles>` `Style Selector=".fkey"` / `.fkey:pointerover"` using `NativeToolbarBackgroundBrush`/`NativeToolbarButtonForegroundBrush`. Add a runtime-reapply check: because `Classes.fkey` is bound to a VM property (not raised on theme change), confirm brushes are `DynamicResource` so `ApplyTheme` picks them up automatically (no new reapply code needed - reuses existing `OnViewModelPropertyChanged`/`ApplyTheme` hook). Extend the existing `MainWindowMenuBarStructureTests`-style text assertions with checks for the ten `Classes.fkey` bindings and unchanged `Command`/`CommandParameter`/`IsEnabled` per button.
**Where**: `src/McGui.App/MainWindow.axaml` (modify), `tests/McGui.App.Tests/McMenuDefinitionsTests.cs` (modify - add facts to `MainWindowMenuBarStructureTests`)
**Depends on**: T5
**Reuses**: `OnViewModelPropertyChanged`/`ApplyTheme` hook (`MainWindow.axaml.cs:80-107`); existing F1-F10 `Button` block (`MainWindow.axaml:135-144`)
**Requirement**: MACUI-10, MACUI-12, MACUI-14

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] All ten F1-F10 buttons have `Classes.fkey="{Binding IsMacOS}"`
- [ ] Each button's existing `Command`/`CommandParameter`/`IsEnabled`/`Content` value is unchanged
- [ ] `.fkey`/`.fkey:pointerover` styles use `DynamicResource` brushes from T3 (so theme switch reapplies them via existing `ApplyTheme` hook, no new code)
- [ ] Gate check passes: `dotnet build McGui.sln && dotnet test McGui.sln`
- [ ] Test count: full App.Tests suite + new facts in `MainWindowMenuBarStructureTests`, all passing (no silent deletions)

**Tests**: unit (text-based XAML structure)
**Gate**: full

**Commit**: `feat(app): style F1-F10 bar as native macOS toolbar`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3

Phase 1:  T1
Phase 2:  T2
Phase 3:  T3 ------→ T4 ------→ T5 ------→ T6
```

Execution is strictly sequential - there is no intra-phase parallelism. Total: 6 tasks, fits a single batch (≤ ~8) - executed inline, no sub-agents.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1: Apply extended client area chrome | 1 method, 1 file | ✅ Granular |
| T2: Mirror menu into native menu bar | 1 XAML block + 1 test file | ✅ Granular |
| T3: Add native brush tokens | 1 file + 1 existing-test edit | ✅ Granular |
| T4: Expose IsMacOS on two ViewModels | 2 one-line properties, cohesive (same concern, same task per spec P3) | ✅ Granular (2-3 related things in same concern = OK) |
| T5: Native file-list styling | 1 XAML file + 1 new test file | ✅ Granular |
| T6: Native F1-F10 styling | 1 XAML file + 1 existing-test edit | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ----------------------- | -------------- | ------ |
| T1 | None | None | ✅ Match |
| T2 | None | None | ✅ Match |
| T3 | None | None | ✅ Match |
| T4 | T3 | T3 → T4 | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | T5 | T5 → T6 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | ----------------------------- | ----------------- | ----------- | ------ |
| T1: ApplyMacChrome | `Window` code-behind, live Avalonia runtime API | none (build gate only) | none | ✅ OK |
| T2: NativeMenu mirror | XAML structure | unit (text-based) | unit | ✅ OK |
| T3: Theme brush tokens | Theme brush tokens | unit (text-based) | unit | ✅ OK |
| T4: IsMacOS properties | ViewModel property | unit | unit | ✅ OK |
| T5: File-list native styling | XAML structure | unit (text-based) | unit | ✅ OK |
| T6: F1-F10 native styling | XAML structure | unit (text-based) | unit | ✅ OK |

No `Tests: none` outside the one row the matrix itself marks "none" (T1, matching existing `ApplySystemAccent` precedent).
