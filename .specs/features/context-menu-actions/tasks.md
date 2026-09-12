# Panel Context Menu Actions Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/context-menu-actions/design.md`
**Status**: Done — Verifier PASS. See `.specs/features/context-menu-actions/validation.md`. Non-blocking gap: CTXM-17 (symlink target row) has no dedicated test (lesson L-021). GUI-interaction ACs need manual UAT - no automation tool available for this native app.

---

## Test Coverage Matrix

> Same matrix as `.specs/features/drag-drop-copy/tasks.md` (identical codebase, same CI: `swift build` + `swift test`, no lint step, no `AGENTS.md`/`CONTRIBUTING.md`), extended with this feature's new layers.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| `MCGuiCore` pure logic (`CopyMovePlanner` extension for zip naming) | unit | All branches; 1:1 to spec ACs | `Tests/MCGuiCoreTests/Services/CopyMovePlannerTests.swift` (extended) | `swift test --filter CopyMovePlannerTests` |
| `MCGuiMacOS` `FileSystemServiceImpl.zip` (real `/usr/bin/zip` `Process`, temp directories) | unit/integration (real filesystem + real process, matching this repo's existing `FileSystemServiceImplCopyMoveTests` style) | Happy path (single item, multiple items), failure path (non-zero exit surfaces a typed error), no partial file left on failure | `Tests/MCGuiMacOSTests/FileSystem/FileSystemServiceImplZipTests.swift` (new) | `swift test --filter FileSystemServiceImplZipTests` |
| `MCGuiMacOS` `FileSystemServiceError` (new `.zipFailed` case) | unit | All 4 locales resolve non-empty, matching the existing `FileSystemServiceErrorLocalizationTests` pattern | `Tests/MCGuiMacOSTests/FileSystem/FileSystemServiceErrorLocalizationTests.swift` (extended) | `swift test --filter FileSystemServiceErrorLocalizationTests` |
| `MCGuiUI` pure/static helpers (`operationTargets`) | unit | 1:1 to spec ACs; matches `PanelViewFileOperationsTests.swift`'s existing static-helper pattern | `Tests/MCGuiUITests/Views/PanelViewFileOperationsTests.swift` (extended) | `swift test --filter PanelViewFileOperationsTests` |
| `MCGuiUI` `InfoDialogViewModel` (async recursive size/count, cancellation) | unit | Every listed edge case (file, empty folder, nested folder, cancellation) has a test | `Tests/MCGuiUITests/ViewModels/InfoDialogViewModelTests.swift` (new) | `swift test --filter InfoDialogViewModelTests` |
| `MCGuiUI` SwiftUI views (context menu wiring, `InfoDialog` layout, `LoadingOverlay` reuse) | none | Interactive UAT only - no view-body test exists anywhere in this repo today | n/a | manual verification during Execute |
| `MCGuiCore.FileSystemService` protocol addition (`zip` method signature) | none | Interface-only, no logic to test | n/a | `swift build` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After a task with a new/extended unit-test suite | `swift test --filter <SuiteName>` |
| Full | After a task with real-process/real-filesystem integration tests, or the last task of a phase | `swift test` |
| Build | After a task with no new tests (interface-only or SwiftUI wiring) | `swift build` |

---

## Execution Plan

10 tasks total - exceeds the ~8-task single-batch threshold. **Offered for batch sub-agent dispatch** (see chat): Batch 1 = Phase 1 + Phase 2 (7 tasks), Batch 2 = Phase 3 (3 tasks), split at the phase boundary between Phase 2 and Phase 3.

### Phase 1: Zip Foundation

```
T1 -> T3
T2 -> T3
```
T4 and T5 have no dependencies (run in task-list order, third and fourth in the phase).

### Phase 2: Info Foundation

```
T6 -> T7
```

### Phase 3: Integration

```
T3 -> T8
T4 -> T8
T5 -> T8
T7 -> T9
T4 -> T10
T8 -> T10
T9 -> T10
```

---

## Task Breakdown

### T1: Add `FileSystemService.zip(_:to:)` to the protocol ✅ Done (protocol requirement + a default throwing extension implementation, mirroring the existing `copy`/`move` `onProgress` pattern, so `FileSystemServiceImpl` and the test `MockFileSystemService` keep building until T3 supplies the real implementation)

**What**: Add `func zip(_ sources: [FileEntry], to destination: URL) async throws` to the `FileSystemService` protocol.
**Where**: `Sources/MCGuiCore/Protocols/FileSystemService.swift`
**Depends on**: None
**Reuses**: N/A - protocol addition
**Requirement**: CTXM-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `FileSystemService` declares `func zip(_ sources: [FileEntry], to destination: URL) async throws`
- [ ] `swift build` succeeds (existing conformers will fail to build until T3 implements it - acceptable within this same phase since T3 follows immediately)

**Tests**: none (interface-only)
**Gate**: build

---

### T2: Add `FileSystemServiceError.zipFailed(reason:)` ✅ Done

**What**: Add a new case to `FileSystemServiceError`, its `errorDescription` (via `NSLocalizedString`), and the corresponding key in all 4 `.lproj` tables under `Sources/MCGuiMacOS/Resources/`.
**Where**: `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift`, `Sources/MCGuiMacOS/Resources/{en,es,pt-BR,pt-PT}.lproj/Localizable.strings`
**Depends on**: None
**Reuses**: Existing `FileSystemServiceError`/`LocalizedError` pattern (AD-005)
**Requirement**: CTXM-11

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `FileSystemServiceError.zipFailed(reason: String)` case exists with a localized `errorDescription` including the reason
- [ ] All 4 locale tables have the new key (`fileSystemError.zipFailed` or similar), matching the existing per-case naming convention
- [ ] `swift test --filter FileSystemServiceErrorLocalizationTests` passes (extended to cover the new case)

**Tests**: unit
**Gate**: quick

---

### T3: Implement `FileSystemServiceImpl.zip(_:to:)` ✅ Done

**What**: Implement `zip` by invoking `/usr/bin/zip -r -X -y <temp-name> <relative source names>` via `Process` (argument array, `currentDirectoryURL` = sources' common parent directory per AD-006), then moving the temp file to `destination` only on a zero exit code; throws `.zipFailed(reason:)` on non-zero exit and removes the temp file.
**Where**: `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift`
**Depends on**: T1, T2
**Reuses**: `FileSystemServiceError` (T2), `FailedItem`/error-surfacing conventions already in this file
**Requirement**: CTXM-08, CTXM-09, CTXM-11

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Zipping a single file into a temp directory produces a valid, non-empty `.zip` at the exact requested `destination`
- [ ] Zipping multiple sources (in one call) produces one `.zip` containing all of them
- [ ] A source that does not exist causes `zip` to exit non-zero, and the thrown error is `.zipFailed(reason:)` with no file left at `destination`
- [ ] `swift test --filter FileSystemServiceImplZipTests` passes

**Tests**: unit
**Gate**: full

**Commit**: `feat(filesystem): add zip archive creation via /usr/bin/zip`

---

### T4: Add `PanelView.operationTargets(for:markedIDs:markedEntries:)` ✅ Done

**What**: A static, testable function generalizing the existing marked-set-or-cursor-fallback rule to an arbitrary entry: returns `markedEntries` if `entry.id` is in `markedIDs`, else `[entry]`.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift`
**Depends on**: None
**Reuses**: Same rule as the existing `operationEntries` computed property (cursor-only variant)
**Requirement**: CTXM-07 (Apagar scope), reused by T8 (Zipar scope)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Returns `markedEntries` unchanged when `entry.id` is in `markedIDs`
- [ ] Returns `[entry]` when `entry.id` is not in `markedIDs`, regardless of what else is marked
- [ ] `swift test --filter PanelViewFileOperationsTests` passes

**Tests**: unit
**Gate**: quick

---

### T5: Add `CopyMovePlanner.zipArchiveName(for:existingNames:)` ✅ Done

**What**: A pure function in `MCGuiCore`: single source → `<name>.zip`; multiple sources → `Archive.zip`; either way, resolved against `existingNames` via the existing `resolvedName` numeric-suffix helper so it never collides.
**Where**: `Sources/MCGuiCore/Services/CopyMovePlanner.swift`
**Depends on**: None
**Reuses**: `CopyMovePlanner.resolvedName` (existing, tested)
**Requirement**: CTXM-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] A single source named `notes.txt` yields `notes.txt.zip` when no conflict exists
- [ ] A single source named `Photos` (a folder) yields `Photos.zip`
- [ ] Two or more sources yield `Archive.zip` when no conflict exists
- [ ] When the computed name already exists in `existingNames`, the next available numeric-suffixed name is returned instead (via `resolvedName`)
- [ ] `swift test --filter CopyMovePlannerTests` passes

**Tests**: unit
**Gate**: quick

---

### T6: Create `InfoDialogViewModel` ✅ Done

**What**: `@MainActor @Observable` class holding `entry`'s static fields plus `totalSize`/`itemCount` (`nil` until computed for a folder, set immediately from `entry.size` for a file); `startSizeCalculationIfNeeded()` recurses via `fileSystemService.listDirectory`, accumulating size and count, supporting `Task` cancellation.
**Where**: `Sources/MCGuiUI/ViewModels/InfoDialogViewModel.swift` (new file)
**Depends on**: None
**Reuses**: Same recursive-listing technique as `DirectoryTreeNodeViewModel.loadChildrenIfNeeded`
**Requirement**: CTXM-14, CTXM-15, CTXM-16, CTXM-17, CTXM-18, CTXM-22

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] For a file entry, `totalSize` is set immediately to `entry.size` and `itemCount` is `nil`
- [ ] For a folder entry, `totalSize`/`itemCount` are `nil` until `startSizeCalculationIfNeeded()` completes, then reflect the recursive sum/count
- [ ] For an empty folder, the calculation resolves to `totalSize == 0`, `itemCount == 0`
- [ ] For a folder containing nested subfolders, the sum includes every level
- [ ] Cancelling the calculation's `Task` stops further accumulation (no crash, fields simply stop updating)
- [ ] `swift test --filter InfoDialogViewModelTests` passes

**Tests**: unit
**Gate**: quick

---

### T7: Create `InfoDialog` view ✅ Done (manual/visual confirmation in the running app still pending - see report)

**What**: SwiftUI view showing `InfoDialogViewModel`'s fields (name, full path, kind, size-or-"Calculando…", permissions via `PermissionBadge`, created/modified dates, symlink target when applicable); `.task` starts the size calculation, cancelled automatically on dismissal.
**Where**: `Sources/MCGuiUI/Views/InfoDialog.swift` (new file), plus the dialog's labels added to all 4 `.lproj` tables under `Sources/MCGuiUI/Resources/`
**Depends on**: T6
**Reuses**: `PermissionBadge`, `ByteCountFormatter` usage pattern from `FileRow`/`ProgressDialog`
**Requirement**: CTXM-14, CTXM-15, CTXM-16, CTXM-17, CTXM-18

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `InfoDialog` renders all fields listed in the spec for a file and for a folder
- [ ] Folder size shows "Calculando…" until the view model's `totalSize` resolves
- [ ] Symlink target is shown only when `entry.isSymlink`
- [ ] All new user-visible strings exist in all 4 locale tables
- [ ] `swift build` succeeds

**Tests**: none (SwiftUI view; behavior already covered by T6's view-model tests)
**Gate**: build

---

### T8: Add `PanelView.beginZip(for:)` and `isZipping` state ✅ Done (uses the existing `LoadingOverlay()` default message rather than a new "Zipando…" locale key, since T8's Where scope is `PanelView.swift` only - no locale files)

**What**: Guarded async function computing the destination via `CopyMovePlanner.zipArchiveName` (T5) and `operationTargets` (T4), calling `fileSystemService.zip` (T3), showing `LoadingOverlay` while `isZipping` is `true`, reloading the panel on success, surfacing failures via the existing `operationErrorMessage`/`ErrorAlert` mechanism.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift`
**Depends on**: T3, T4, T5
**Reuses**: `LoadingOverlay`, `operationErrorMessage`/`displayedErrorMessage`/`ErrorAlert`, `viewModel.load()`
**Requirement**: CTXM-08, CTXM-09, CTXM-10, CTXM-11, CTXM-12, CTXM-13, CTXM-21

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `beginZip(for:)` is a no-op while an operation (`operationTask` or `isZipping`) is already running
- [ ] On success, the panel reloads and the new archive appears in the listing
- [ ] On failure, `operationErrorMessage` is set and shown via the existing `ErrorAlert` overlay, no partial file left (guaranteed by T3)
- [ ] `LoadingOverlay` (or equivalent "Zipando…" text) is visible in the panel's `ZStack` while `isZipping` is `true`
- [ ] `swift build` succeeds

**Tests**: none (orchestration glue over already-tested T3/T4/T5 pieces, same convention as the existing untested `beginCopyOrMove`/`beginDelete`)
**Gate**: build

---

### T9: Add `PanelView.beginInfo(for:)` and `infoViewModel` state ✅ Done

**What**: Constructs an `InfoDialogViewModel` (T6) for the given entry, stores it in `@State private var infoViewModel`, presents `InfoDialog` (T7) via `.sheet`.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift`
**Depends on**: T7
**Reuses**: Existing `.sheet`/`presented(_:)` pattern already used for `mkdirViewModel`, `deleteViewModel`, etc.
**Requirement**: CTXM-14

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `beginInfo(for:)` sets `infoViewModel` to a new `InfoDialogViewModel` for the given entry
- [ ] A `.sheet(isPresented: presented($infoViewModel))` shows `InfoDialog` when set, dismissing clears `infoViewModel`
- [ ] `swift build` succeeds

**Tests**: none (SwiftUI wiring, view-model behavior already covered by T6)
**Gate**: build

---

### T10: Replace the placeholder context menu with the full 6-item menu ✅ Done

**What**: Replace `.contextMenu { Text(entry.name) }` with a real `Menu`/`contextMenu` builder offering Abrir (`activate(entry)`), Selecionar/Desselecionar (label from `markedIDs.contains(entry.id)`, action toggles via `PanelCommands.toggleSelection(markedIDs, id: entry.id, ...)`), Zipar (`beginZip(for: entry)`, T8), Editar (`onEditFile(entry)`), Apagar (`Self.makeDeleteDialog(selection: operationTargets(for: entry, ...))`, T4), Mostrar Informações (`beginInfo(for: entry)`, T9); add all 6 item labels to all 4 locale tables.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift` (`entryList`), `Sources/MCGuiUI/Resources/{en,es,pt-BR,pt-PT}.lproj/Localizable.strings`
**Depends on**: T4, T8, T9
**Reuses**: `activate`, `PanelCommands.toggleSelection`, `onEditFile`, `Self.makeDeleteDialog`, `operationTargets` (T4), `beginZip` (T8), `beginInfo` (T9)
**Requirement**: CTXM-01, CTXM-02, CTXM-03, CTXM-04, CTXM-05, CTXM-06, CTXM-07, CTXM-19

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Right-clicking a row shows all 6 items: Abrir, Selecionar/Desselecionar, Zipar, Editar, Apagar, Mostrar Informações
- [ ] Right-clicking empty panel space does not show this per-row menu
- [ ] Manual check: Abrir on a directory navigates into it; Abrir on a file opens the viewer
- [ ] Manual check: Selecionar/Desselecionar label matches the row's current mark state and toggles it correctly
- [ ] Manual check: Editar opens the editor; Apagar opens the same delete dialog F8 produces, targeting the marked set when the row is marked
- [ ] Manual check: Zipar and Mostrar Informações work as verified in T8/T9
- [ ] `swift build` succeeds

**Tests**: none (SwiftUI menu wiring; every action it calls is already unit-tested at its own layer)
**Gate**: build

**Commit**: `feat(panel): add context menu with open, select, zip, edit, delete, info`

---

## Phase Execution Map

```
Phase 1 -> Phase 2 -> Phase 3

T1 -> T3
T2 -> T3
T6 -> T7
T3 -> T8
T4 -> T8
T5 -> T8
T7 -> T9
T4 -> T10
T8 -> T10
T9 -> T10
```

T4 and T5 (Phase 1) have no dependencies; they run in task-list order after T1-T3 within Phase 1.

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: `zip` protocol method | 1 method signature, 1 file | ✅ Granular |
| T2: `zipFailed` error case | 1 case + 4 locale entries (one cohesive concern: the error's localized text) | ✅ Granular |
| T3: `zip` implementation | 1 method, 1 file | ✅ Granular |
| T4: `operationTargets` | 1 function, 1 file | ✅ Granular |
| T5: `zipArchiveName` | 1 function, 1 file | ✅ Granular |
| T6: `InfoDialogViewModel` | 1 class, 1 file | ✅ Granular |
| T7: `InfoDialog` view | 1 view, 1 file (+ 4 locale files for its own labels - one cohesive concern) | ✅ Granular |
| T8: `beginZip` + `isZipping` | 1 function + 1 state var, 1 file (cohesive: the state exists only to back this function) | ✅ Granular |
| T9: `beginInfo` + `infoViewModel` | 1 function + 1 state var, 1 file (same cohesive pairing as T8) | ✅ Granular |
| T10: context menu wiring | 1 menu builder, 1 file (+ 4 locale files for its own labels) | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | Standalone, feeds T3 | ✅ Match |
| T2 | None | Standalone, feeds T3 | ✅ Match |
| T3 | T1, T2 | T1 → T3, T2 → T3 | ✅ Match |
| T4 | None | Standalone, feeds T8 and T10 | ✅ Match |
| T5 | None | Standalone, feeds T8 | ✅ Match |
| T6 | None | Standalone, feeds T7 | ✅ Match |
| T7 | T6 | T6 → T7 | ✅ Match |
| T8 | T3, T4, T5 | T3 → T8, T4 → T8, T5 → T8 | ✅ Match |
| T9 | T7 | T7 → T9 | ✅ Match |
| T10 | T4, T8, T9 | T4 → T10, T8 → T10, T9 → T10 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: protocol addition | Protocol (interface-only) | none | none | ✅ OK |
| T2: `zipFailed` case | `FileSystemServiceError` (unit) | unit | unit | ✅ OK |
| T3: `zip` implementation | `FileSystemServiceImpl` (unit/integration) | unit | unit | ✅ OK |
| T4: `operationTargets` | Static helper (unit) | unit | unit | ✅ OK |
| T5: `zipArchiveName` | `MCGuiCore` pure logic (unit) | unit | unit | ✅ OK |
| T6: `InfoDialogViewModel` | ViewModel (unit) | unit | unit | ✅ OK |
| T7: `InfoDialog` view | SwiftUI view (none) | none | none | ✅ OK |
| T8: `beginZip` | SwiftUI orchestration glue (none) | none | none | ✅ OK |
| T9: `beginInfo` | SwiftUI orchestration glue (none) | none | none | ✅ OK |
| T10: context menu | SwiftUI view (none) | none | none | ✅ OK |

---

## Tips

- **Phases are ordered** - Each phase completes before the next; tasks run in order within a phase
- **Reuses = Token saver** - Always reference existing code
- **One commit per task** - Plan the commit message format in advance
