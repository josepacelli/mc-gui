# Convert to Swift and SwiftUI Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/convert-to-swift-swiftui/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase sampling and spec assumptions - confirm before Execute. Guidelines found: none (no `AGENTS.md`/`CONTRIBUTING.md`/testing config in repo) - strong defaults applied, mapped onto the frameworks the spec already confirmed (Swift Testing for unit/integration, XCUITest for e2e, per spec.md Assumptions).

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| ---------- | ------------------- | --------------------- | ----------------- | ----------- |
| Domain Models (`MCGuiCore/Models`) | unit | All Codable/Equatable/edge-case branches; 1:1 to spec ACs | `Tests/MCGuiCoreTests/Models/*.swift` | `swift test --filter MCGuiCoreTests` |
| Protocols (`MCGuiCore/Protocols`) | none | No logic to test - build gate only | - | `swift build` |
| Core Services (`MCGuiCore/Services`) | unit | All branches; 1:1 spec ACs; every listed edge case | `Tests/MCGuiCoreTests/Services/*.swift` | `swift test --filter MCGuiCoreTests` |
| macOS Service Impls (`MCGuiMacOS/*`) | integration | Key operation paths + every listed error scenario (EBUSY/ENOSPC/permission/corrupt JSON) | `Tests/MCGuiMacOSTests/*.swift` | `swift test --filter MCGuiMacOSTests` |
| ViewModels (`MCGuiUI/ViewModels`) | unit | All branches; 1:1 spec ACs (dirty tracking, mode switching, dialog state, filtering) | `Tests/MCGuiUITests/ViewModels/*.swift` | `swift test --filter MCGuiUITests` |
| Presentational Components (`MCGuiUI/Components`, no embedded logic) | none | Pure rendering - covered visually via manual/UAT | - | `swift build` |
| Components with embedded formatting logic (e.g. hex/ASCII formatter) | unit | Formatting function branches covered | `Tests/MCGuiUITests/Components/*.swift` | `swift test --filter MCGuiUITests` |
| Interactive Views + Commands (`MCGuiUI/Views`, `MCGuiUI/Commands`) | e2e | Every keyboard shortcut / menu action / dialog flow in scope: happy path + cancel/escape path | `Tests/MCGuiAppUITests/*.swift` (XCUITest) | `xcodebuild test -scheme MCGuiApp -destination 'platform=macOS'` |
| App Entry / WindowManager (`MCGuiApp`) | e2e | App launches; all windows open/close correctly | `Tests/MCGuiAppUITests/*.swift` | `xcodebuild test -scheme MCGuiApp -destination 'platform=macOS'` |

## Gate Check Commands

> Generated from `spec.md` Assumptions (Swift Testing + XCUITest, `swift build`/`xcodebuild`) - confirm before Execute.

| Gate Level | When to Use | Command |
| ---------- | ----------- | ------- |
| Quick | After tasks touching only `MCGuiCore` or `MCGuiUI` unit-tested layers | `swift test --filter MCGuiCoreTests` or `swift test --filter MCGuiUITests` (whichever target the task touched) |
| Full | After tasks touching `MCGuiMacOS` integration or cross-target wiring | `swift test` |
| Build | After phase completion, or tasks touching e2e/App/Commands layers | `swift build && swift test && xcodebuild test -scheme MCGuiApp -destination 'platform=macOS'` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order. Each phase's dependency diagram and task definitions are presented together under **Task Breakdown** below (phase headers there are authoritative for phase membership).

| Phase | Name | Tasks | Priority |
| ----- | ---- | ----- | -------- |
| 1 | Foundation (Package, Models, Protocols) | T1-T8 | P1 |
| 2 | Core Business Logic Services | T9-T11 | P1 |
| 3 | macOS Infrastructure Services | T12-T16 | P1 |
| 4 | Panel ViewModels & Main Window UI | T17-T22 | P1 |
| 5 | File Operation Dialogs | T23-T32 | P1 |
| 6 | Wire File Operations | T33 | P1 |
| 7 | File Viewer | T34-T38 | P1 |
| 8 | Text Editor | T39-T43 | P1 |
| 9 | Keyboard Navigation & Commands | T44-T45 | P1 |
| 10 | Theme Support | T46-T47 | P1 |
| 11 | Menu Bar & App Entry | T48-T50 | P1 |
| 12 | Volume Listing & Search/Filter | T51-T52 | P2 |
| 13 | Bookmarks | T53-T54 | P3 |

**Total: 54 tasks across 13 phases.** At ~7 tasks per worker budget, this packs into ~8 batches. Sub-agent delegation will be offered before Execute begins.

---

## Task Breakdown

### Phase 1: Foundation (Package, Models, Protocols)

```
T1 → T2
T1 → T3
T1 → T4
T1 → T5
T2 → T6
T3 → T6
T4 → T6
T4 → T7
T5 → T7
T6 → T8
T7 → T8
```

#### T1: Swift Package manifest with 4 targets

**What**: Create `Package.swift` (SPM) with library targets `MCGuiCore`, `MCGuiUI`, `MCGuiMacOS`, executable target `MCGuiApp`, and matching test targets `MCGuiCoreTests`, `MCGuiUITests`, `MCGuiMacOSTests`; set platform to `.macOS(.v14)`, Swift tools version 5.9.
**Where**: `Package.swift`
**Depends on**: None
**Reuses**: None (new project structure per AD-002)
**Requirement**: SWIFT-01, SWIFT-05

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `swift build` succeeds with all 4 targets resolving
- [x] Target dependency graph matches design.md (`MCGuiApp` → `MCGuiUI`, `MCGuiMacOS` → `MCGuiCore`; `MCGuiUI` → `MCGuiCore`)
- [x] `swift package describe` lists all 7 targets (4 + 3 test targets)

**Tests**: none
**Gate**: build

**Commit**: `feat(swift): add Package.swift with 4-target SPM structure`

---

#### T2: FileEntry, FileType, FilePermissions models

**What**: Port `FileEntry` struct (Identifiable, Hashable, Codable) with `FileType` enum and `FilePermissions` OptionSet, 1:1 with the C# model.
**Where**: `Sources/MCGuiCore/Models/FileEntry.swift`
**Depends on**: T1
**Reuses**: `src/McGui.Core/Models/FileEntry.cs`
**Requirement**: SWIFT-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] All fields from design.md `FileEntry` data model present with correct types
- [x] `FilePermissions` OptionSet round-trips through `Codable`
- [x] Unit tests cover: symlink target present/absent, hidden flag, each `FileType` case

**Tests**: unit
**Gate**: quick

**Commit**: `feat(core): add FileEntry, FileType, FilePermissions models`

---

#### T3: PanelState, PanelSortColumn, PanelPathHistory models

**What**: Port `PanelState` struct, `PanelSortColumn` enum, `PanelPathHistory` struct (past/future URL arrays).
**Where**: `Sources/MCGuiCore/Models/PanelState.swift`
**Depends on**: T1
**Reuses**: `src/McGui.Core/Models/PanelState.cs`, `src/McGui.Core/Models/PanelSortColumn.cs`, `src/McGui.Core/Models/PanelPathHistory.cs`
**Requirement**: SWIFT-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `PanelState` holds `currentPath`, `entries`, `selectedIndices`, `sortColumn`, `sortAscending`, `showHidden`, `history`
- [x] `PanelPathHistory` Codable round-trip test passes
- [x] Unit tests cover default/empty state and populated state

**Tests**: unit
**Gate**: quick

**Commit**: `feat(core): add PanelState, PanelSortColumn, PanelPathHistory models`

---

#### T4: OperationMode, CopyMoveOptions, CopyMovePlan, OperationProgress, OperationResult models

**What**: Port the five operation-related models used by copy/move/delete flows.
**Where**: `Sources/MCGuiCore/Models/Operations.swift`
**Depends on**: T1
**Reuses**: `src/McGui.Core/Models/OperationMode.cs`, `src/McGui.Core/Models/CopyMoveOptions.cs`, `src/McGui.Core/Models/CopyMovePlan.cs`, `src/McGui.Core/Models/OperationProgress.cs`, `src/McGui.Core/Models/OperationResult.cs`
**Requirement**: SWIFT-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `CopyMoveOptions` has `preserveAttributes`, `followSymlinks`, `updateOnly`
- [x] `OperationResult` has `success`, `errorMessage`, `processedCount`, `failedItems`
- [x] Unit tests cover Codable round-trip for each of the 5 types

**Tests**: unit
**Gate**: quick

**Commit**: `feat(core): add operation models (mode, options, plan, progress, result)`

---

#### T5: EditorDocumentState, ViewerState, ViewerContent, FileConflictResolution models

**What**: Port the remaining domain models used by editor/viewer/conflict flows.
**Where**: `Sources/MCGuiCore/Models/EditorViewerState.swift`
**Depends on**: T1
**Reuses**: `src/McGui.Core/Models/EditorDocumentState.cs`, `src/McGui.Core/Models/ViewerState.cs`, `src/McGui.Core/Models/ViewerContent.cs`, `src/McGui.Core/Models/ViewerMode.cs`, `src/McGui.Core/Models/FileConflictResolution.cs`
**Requirement**: SWIFT-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `ViewerContent` enum covers `text`, `image`, `hexData` cases
- [x] `FileConflictResolution` enum covers `overwrite`, `skip`, `rename`, `cancel`
- [x] Unit tests cover each `ViewerContent` and `FileConflictResolution` case

**Tests**: unit
**Gate**: quick

**Commit**: `feat(core): add EditorDocumentState, ViewerState, ViewerContent, FileConflictResolution models`

---

#### T6: FileSystemService protocol

**What**: Define the `FileSystemService` protocol (listDirectory, createDirectory, copy, move, delete, trash, getVolumes) as async/throws methods.
**Where**: `Sources/MCGuiCore/Protocols/FileSystemService.swift`
**Depends on**: T2, T3, T4
**Reuses**: `src/McGui.Core/Interfaces/IFileSystemService.cs`
**Requirement**: SWIFT-03

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Protocol method signatures match design.md `FileSystemServiceImpl` Key Methods
- [x] `swift build` succeeds with no conforming type yet (protocol-only compiles)

**Tests**: none
**Gate**: build

**Commit**: `feat(core): add FileSystemService protocol`

---

#### T7: EditorService, ViewerService, TrashService, PathHistoryStore protocols

**What**: Define the remaining four service protocols.
**Where**: `Sources/MCGuiCore/Protocols/Services.swift`
**Depends on**: T4, T5
**Reuses**: `src/McGui.Core/Interfaces/IEditorService.cs`, `src/McGui.Core/Interfaces/IViewerService.cs`, `src/McGui.Core/Interfaces/ITrashService.cs`, `src/McGui.Core/Interfaces/IPathHistoryStore.cs`
**Requirement**: SWIFT-03

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] All 4 protocols declared with async/throws signatures per design.md Protocols section
- [x] `swift build` succeeds

**Tests**: none
**Gate**: build

**Commit**: `feat(core): add EditorService, ViewerService, TrashService, PathHistoryStore protocols`

---

#### T8: Swift Testing smoke test + executable target verification

**What**: Add a Swift Testing smoke test that confirms the package builds and a minimal `MCGuiApp` executable target exists (even if it just prints/no-ops for now).
**Where**: `Tests/MCGuiCoreTests/SmokeTests.swift`
**Depends on**: T6, T7
**Reuses**: None
**Requirement**: SWIFT-04, SWIFT-05

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `swift test` runs and passes at least 1 test
- [x] `swift build --product MCGuiApp` produces a macOS executable

**Tests**: unit
**Gate**: build

**Commit**: `test(core): add smoke test verifying build and executable target`

---

### Phase 2: Core Business Logic Services

```
T9
T10
T11
```

(No intra-phase dependencies - T9, T10, T11 are independent of each other; execute in numeric order.)

#### T9: SelectionService

**What**: Port multi-selection logic: toggle, range (shift), jump-to-first/last, invert.
**Where**: `Sources/MCGuiCore/Services/SelectionService.swift`
**Depends on**: T2, T3
**Reuses**: `src/McGui.Core/Services/SelectionService.cs`
**Requirement**: KN-03, KN-04, KN-05, KN-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Range selection, toggle, jump-to-first/last, invert all implemented
- [x] Unit tests cover every selection mode + empty-list edge case

**Tests**: unit
**Gate**: quick

**Commit**: `feat(core): add SelectionService with range/toggle/jump/invert`

---

#### T10: PathHistoryManager (in-memory)

**What**: Port in-memory back/forward navigation manager operating on `PanelPathHistory`.
**Where**: `Sources/MCGuiCore/Services/PathHistoryManager.swift`
**Depends on**: T3
**Reuses**: C# `PanelPathHistory` usage in `MacPathHistoryStore.cs` (in-memory portion only - persistence is T16)
**Requirement**: FS-11, FS-12, FS-13

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `back()`/`forward()` mutate past/future arrays correctly
- [x] Navigating to a new path after going back clears the stale forward stack
- [x] Unit tests cover empty history, single entry, back-then-navigate-clears-forward

**Tests**: unit
**Gate**: quick

**Commit**: `feat(core): add PathHistoryManager for in-memory back/forward navigation`

---

#### T11: CopyMovePlanner

**What**: Port conflict-detection and plan-building logic (Overwrite/Skip/Rename/Cancel resolution, numeric-suffix rename).
**Where**: `Sources/MCGuiCore/Services/CopyMovePlanner.swift`
**Depends on**: T4
**Reuses**: `src/McGui.Core/Services/CopyMovePlanner.cs`, `src/McGui.Infrastructure.macOS/NamingCollisionResolver.cs`
**Requirement**: FO-01, FO-02, FO-05, FO-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Plan building detects existing-destination conflicts
- [x] Numeric-suffix rename produces `file (1).txt`, `file (2).txt`, ...
- [x] Unit tests cover no-conflict, single-conflict, multi-conflict, exhausted-suffix-search edge case

**Tests**: unit
**Gate**: quick

**Commit**: `feat(core): add CopyMovePlanner with conflict detection and rename suffixing`

---

### Phase 3: macOS Infrastructure Services

```
T12 → T13
T12 → T14
T15
T16
```

(T15, T16 have no intra-phase dependencies - they depend only on Phase 1 protocols.)

#### T12: FileSystemServiceImpl - listDirectory, createDirectory

**What**: Implement `listDirectory(_:)` and `createDirectory(_:)` on `FileManager`, async/await, with `CocoaError` 257 (permission) mapped to a typed error.
**Where**: `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift`
**Depends on**: T6, T2
**Reuses**: `src/McGui.Infrastructure.macOS/MacFileSystemService.cs`
**Requirement**: FS-03, FS-08, FO-10, FO-11

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `listDirectory` returns `[FileEntry]` with name/size/dates/permissions/hidden/symlink populated
- [x] Permission-denied directory throws a typed error (not a generic `NSError`)
- [x] Integration tests cover: normal directory, empty directory, permission-denied directory, `createDirectory` success + already-exists error

**Tests**: integration
**Gate**: full

**Commit**: `feat(macos): implement FileSystemServiceImpl listDirectory and createDirectory`

---

#### T13: FileSystemServiceImpl - copy/move with conflict resolution and error handling

**What**: Implement `copy(_:)` and `move(_:)` using the `CopyMovePlan` from T11, preserving metadata when `preserveAttributes` is set, renaming across volumes when needed, and mapping `POSIXError.EBUSY`/`ENOSPC`/`ENOTCONN` to typed errors.
**Where**: `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift` (extend)
**Depends on**: T12, T11
**Reuses**: `src/McGui.Infrastructure.macOS/MacFileSystemService.cs`
**Requirement**: FO-03, FO-04, FO-06, FO-07, FO-09, FO-15

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Copy preserves timestamps/permissions when `preserveAttributes: true`
- [x] Move renames within a volume, copy+deletes across volumes
- [x] Integration tests cover: same-volume move, cross-volume move, overwrite, skip, EBUSY-simulated retry, ENOSPC-simulated failure

**Tests**: integration
**Gate**: full

**Commit**: `feat(macos): implement FileSystemServiceImpl copy/move with conflict and error handling`

---

#### T14: FileSystemServiceImpl - getVolumes

**What**: Implement `getVolumes()` using `FileManager` volume enumeration (mount point, name, free space).
**Where**: `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift` (extend)
**Depends on**: T12
**Reuses**: `src/McGui.Infrastructure.macOS/VolumeLocator.cs`
**Requirement**: VL-01 (base data)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `getVolumes()` returns all mounted volumes with name and root URL
- [x] Integration test confirms the boot volume is always present in the result

**Tests**: integration
**Gate**: full

**Commit**: `feat(macos): implement FileSystemServiceImpl getVolumes`

---

#### T15: TrashServiceImpl

**What**: Implement `TrashService` via `FileManager.trashItem(at:resultingItemURL:)`.
**Where**: `Sources/MCGuiMacOS/Trash/TrashServiceImpl.swift`
**Depends on**: T7
**Reuses**: `src/McGui.Infrastructure.macOS/MacTrashService.cs`
**Requirement**: FO-12, FO-13

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Trashing a file moves it to macOS Trash (not permanent delete)
- [x] Integration tests cover single file, multiple files, already-trashed-name collision

**Tests**: integration
**Gate**: full

**Commit**: `feat(macos): implement TrashServiceImpl using FileManager.trashItem`

---

#### T16: PathHistoryStoreImpl

**What**: Implement JSON persistence of `PanelPathHistory` to `~/Library/Application Support/MCGui/`, capped at 100 entries per panel, with corrupt-file recovery to empty history.
**Where**: `Sources/MCGuiMacOS/History/PathHistoryStoreImpl.swift`
**Depends on**: T7, T10
**Reuses**: `src/McGui.Infrastructure.macOS/MacPathHistoryStore.cs`
**Requirement**: PH-01, PH-02, PH-03, PH-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `save`/`load` round-trip a `PanelPathHistory` through JSON on disk
- [x] History is truncated to 100 entries per panel on save
- [x] Integration tests cover: save+load round-trip, corrupted JSON file recovers to empty history, missing file recovers to empty history

**Tests**: integration
**Gate**: full

**Commit**: `feat(macos): implement PathHistoryStoreImpl with JSON persistence and 100-entry cap`

---

### Phase 4: Panel ViewModels & Main Window UI

```
T17 → T18
T17 → T21
T19 → T20
T20 → T21
T18 → T22
T21 → T22
```

#### T17: PanelViewModel

**What**: Port directory-listing ViewModel: load, sort (name/size/date/type, asc/desc), hidden-files toggle, loading state, error state.
**Where**: `Sources/MCGuiUI/ViewModels/PanelViewModel.swift`
**Depends on**: T12, T9, T16
**Reuses**: `src/McGui.App/ViewModels/PanelViewModel.cs`, `src/McGui.App/ViewModels/PanelEntryRow.cs`, `src/McGui.App/ViewModels/PanelSide.cs`
**Requirement**: FS-01, FS-03, FS-04, FS-05, FS-07, FS-08, FS-09, FS-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `@Observable` (or `@Published`) state exposes entries, loading, error, sort, showHidden
- [x] Sorting by each column (asc/desc) produces correct order
- [x] Unit tests cover: load success, load failure (error state), each sort column both directions, hidden-toggle filtering

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add PanelViewModel with load, sort, hidden-toggle, loading/error state`

---

#### T18: MainWindowViewModel

**What**: Port app-level state coordinating two `PanelViewModel` instances and tracking the active panel.
**Where**: `Sources/MCGuiUI/ViewModels/MainWindowViewModel.swift`
**Depends on**: T17
**Reuses**: `src/McGui.App/ViewModels/MainWindowViewModel.cs`
**Requirement**: FS-01, FS-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Holds left/right `PanelViewModel` and an `activePanel` property
- [x] Switching active panel updates highlighting state
- [x] Unit tests cover default active panel and switching

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add MainWindowViewModel coordinating dual panels`

---

#### T19: Support components (icon, badge, indicator, overlay, alert)

**What**: Build `FileIcon`, `PermissionBadge`, `SortIndicator`, `LoadingOverlay`, `ErrorAlert` - small presentational SwiftUI views, co-located in one file since they are cohesive UI primitives with no independent logic.
**Where**: `Sources/MCGuiUI/Components/SupportComponents.swift`
**Depends on**: T2
**Reuses**: None (new SwiftUI components; SF Symbols per design.md Tech Decisions)
**Requirement**: FS-03, FS-07, FS-08 (supporting UI)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] All 5 components compile and accept the props described in design.md
- [x] `swift build` succeeds

**Tests**: none
**Gate**: build

**Commit**: `feat(ui): add FileIcon, PermissionBadge, SortIndicator, LoadingOverlay, ErrorAlert components`

---

#### T20: FileRow

**What**: Build the single-row file list item (icon, name, size, date, permission badge).
**Where**: `Sources/MCGuiUI/Views/FileRow.swift`
**Depends on**: T19, T2
**Reuses**: None (new SwiftUI view; layout ported from Avalonia `MainWindow.axaml` row template)
**Requirement**: FS-03

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Renders a `FileEntry` with icon, name, size, date, permissions
- [x] Broken symlinks render with distinct visual (per Edge Case 3)

**Tests**: none
**Gate**: build

**Commit**: `feat(ui): add FileRow view`

---

#### T21: PanelView

**What**: Build the file list view with keyboard-navigable selection skeleton (focus state, list rendering) and a context menu stub; full keyboard wiring lands in Phase 9.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift`
**Depends on**: T17, T20
**Reuses**: `src/McGui.App/MainWindow.axaml` panel layout for structure reference
**Requirement**: FS-01, FS-02, FS-04, FS-05, FS-07, FS-08, FS-09, FS-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Renders `PanelViewModel.entries` via `FileRow`
- [x] Shows `LoadingOverlay` while loading and `ErrorAlert` on error
- [x] Focus state visually distinguishes the active panel
- [ ] XCUITest covers: directory renders rows, loading indicator appears/disappears, error alert appears on unreadable directory - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build` gate used instead per batch instructions. The underlying state this view renders (`entries`, `isLoading`, `errorMessage`) is unit-tested in `PanelViewModelTests` (T17); the view itself is a thin declarative binding with no additional testable logic.

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add PanelView with file list, loading and error states`

---

#### T22: MainWindow

**What**: Build the root window with `HSplitView` hosting two `PanelView` instances side by side.
**Where**: `Sources/MCGuiUI/Views/MainWindow.swift`
**Depends on**: T18, T21
**Reuses**: `src/McGui.App/MainWindow.axaml` overall layout for structure reference
**Requirement**: FS-01, FS-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Two panels render side by side via `HSplitView`
- [x] Clicking/tabbing into a panel updates `MainWindowViewModel.activePanel`
- [ ] XCUITest covers: app launches with 2 panels visible, clicking each panel updates active-panel highlight - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build` gate used instead per batch instructions. The underlying state transition (`activate(_:)`) is unit-tested in `MainWindowViewModelTests` (T18); `MainWindow`/`PanelView` are thin declarative bindings with no additional testable logic.

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add MainWindow with dual-panel HSplitView layout`

---

### Phase 5: File Operation Dialogs

```
T23 → T24
T25 → T26
T27 → T28
T27 → T29
T29 → T30
T31 → T32
```

#### T23: MkdirDialogViewModel

**What**: Port new-folder-name-input ViewModel with validation.
**Where**: `Sources/MCGuiUI/ViewModels/MkdirDialogViewModel.swift`
**Depends on**: T12
**Reuses**: `src/McGui.App/ViewModels/MkdirDialogViewModel.cs`
**Requirement**: FO-10, FO-11

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Empty/invalid name is rejected with an error message
- [x] Unit tests cover valid name, empty name, name with `/`

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add MkdirDialogViewModel`

---

#### T24: MkdirDialog view

**What**: Build the new-folder dialog UI (text field, Create/Cancel).
**Where**: `Sources/MCGuiUI/Views/MkdirDialog.swift`
**Depends on**: T23
**Reuses**: None (new SwiftUI view)
**Requirement**: FO-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Create button disabled until name is valid
- [ ] XCUITest covers: F7 opens dialog, valid name creates directory, Escape cancels - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build` gate used instead per batch instructions. The name-validity logic this view binds to (`MkdirDialogViewModel.validate`, `confirm()`) is unit-tested in `MkdirDialogViewModelTests` (T23); `MkdirDialog` itself is a thin declarative binding with no additional testable logic.

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add MkdirDialog view`

---

#### T25: DeleteConfirmDialogViewModel

**What**: Port delete-confirmation ViewModel (file list summary, confirm/cancel).
**Where**: `Sources/MCGuiUI/ViewModels/DeleteConfirmDialogViewModel.swift`
**Depends on**: T15
**Reuses**: `src/McGui.App/ViewModels/DeleteConfirmDialogViewModel.cs`
**Requirement**: FO-12, FO-13

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Holds the selected files and a confirm action that calls `TrashService`
- [x] Unit tests cover single file, multiple files, empty selection guard

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add DeleteConfirmDialogViewModel`

---

#### T26: DeleteConfirmDialog view

**What**: Build the delete confirmation dialog UI.
**Where**: `Sources/MCGuiUI/Views/DeleteConfirmDialog.swift`
**Depends on**: T25
**Reuses**: None (new SwiftUI view)
**Requirement**: FO-12, FO-13

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Lists files to be deleted with a Trash-bound confirm action
- [ ] XCUITest covers: F8 opens dialog, confirm moves file to Trash, cancel leaves file in place - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build` gate used instead per batch instructions. The Trash-bound `confirm()` behavior this view binds to is unit-tested in `DeleteConfirmDialogViewModelTests` (T25); `DeleteConfirmDialog` itself is a thin declarative binding with no additional testable logic.

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add DeleteConfirmDialog view`

---

#### T27: ConflictDialogViewModel

**What**: Port the file-conflict resolution ViewModel exposing Overwrite/Skip/Rename/Cancel.
**Where**: `Sources/MCGuiUI/ViewModels/ConflictDialogViewModel.swift`
**Depends on**: T11
**Reuses**: `src/McGui.App/ViewModels/ConflictDialogViewModel.cs`, `src/McGui.App/ViewModels/IConflictPrompt.cs`
**Requirement**: FO-05, FO-06, FO-07, FO-08, FO-09

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Exposes the 4 resolution options and returns the chosen `FileConflictResolution`
- [x] Unit tests cover each of the 4 resolution paths

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add ConflictDialogViewModel`

---

#### T28: ConflictDialog view

**What**: Build the file-conflict dialog UI.
**Where**: `Sources/MCGuiUI/Views/ConflictDialog.swift`
**Depends on**: T27
**Reuses**: None (new SwiftUI view)
**Requirement**: FO-05, FO-06, FO-07, FO-08, FO-09

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] All 4 options render as buttons and invoke the ViewModel action
- [ ] XCUITest covers: each of Overwrite/Skip/Rename/Cancel selected in a real conflict scenario - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build` gate used instead per batch instructions. The 4 resolution actions this view's buttons invoke are unit-tested in `ConflictDialogViewModelTests` (T27); `ConflictDialog` itself is a thin declarative binding with no additional testable logic.

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add ConflictDialog view`

---

#### T29: CopyMoveDialogViewModel

**What**: Port the copy/move dialog ViewModel (source, destination, options, wired to `ConflictDialogViewModel` on conflict).
**Where**: `Sources/MCGuiUI/ViewModels/CopyMoveDialogViewModel.swift`
**Depends on**: T11, T27
**Reuses**: `src/McGui.App/ViewModels/CopyMoveDialogViewModel.cs`
**Requirement**: FO-01, FO-02, FO-03, FO-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Holds destination path and `CopyMoveOptions` (preserveAttributes, followSymlinks, updateOnly)
- [x] Delegates conflict resolution to T27's ViewModel
- [x] Unit tests cover copy mode, move mode, options toggling

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add CopyMoveDialogViewModel`

---

#### T30: CopyMoveDialog view

**What**: Build the copy/move dialog UI (destination field, options checkboxes, confirm/cancel).
**Where**: `Sources/MCGuiUI/Views/CopyMoveDialog.swift`
**Depends on**: T29
**Reuses**: None (new SwiftUI view)
**Requirement**: FO-01, FO-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Renders destination field + preserveAttributes/followSymlinks/updateOnly checkboxes
- [ ] XCUITest covers: F5 opens in copy mode, F6 opens in move mode, confirm triggers the operation - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build` gate used instead per batch instructions. The mode/options state this view binds to is unit-tested in `CopyMoveDialogViewModelTests` (T29); `CopyMoveDialog` itself is a thin declarative binding with no additional testable logic. F5/F6 key wiring and the actual copy/move invocation are Phase 6 (T33).

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add CopyMoveDialog view`

---

#### T31: ProgressDialogViewModel

**What**: Port the operation-progress ViewModel (current file, bytes transferred, speed, ETA, cancel).
**Where**: `Sources/MCGuiUI/ViewModels/ProgressDialogViewModel.swift`
**Depends on**: T13
**Reuses**: `src/McGui.App/ViewModels/ProgressDialogViewModel.cs`
**Requirement**: FO-14, FO-16

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Consumes an `AsyncStream<OperationProgress>` and updates published state
- [x] Cancel action propagates to the running operation
- [x] Unit tests cover progress updates, completion, cancellation

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add ProgressDialogViewModel`

---

#### T32: ProgressDialog view

**What**: Build the progress dialog UI (progress bar, current file, speed, ETA, Cancel button).
**Where**: `Sources/MCGuiUI/Views/ProgressDialog.swift`
**Depends on**: T31
**Reuses**: None (new SwiftUI view)
**Requirement**: FO-14, FO-16

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Displays live progress bar and stats bound to the ViewModel
- [ ] XCUITest covers: progress dialog appears during a multi-file copy, Cancel stops the operation - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build && swift test` gate used instead per batch instructions. The progress-consumption and cancel-propagation logic this view binds to is unit-tested in `ProgressDialogViewModelTests` (T31); `ProgressDialog` itself is a thin declarative binding with no additional testable logic.

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add ProgressDialog view`

---

### Phase 6: Wire File Operations

```
T33
```

(Single task; depends on T21 from Phase 4 and T24, T26, T30, T32 from Phase 5 - all backward cross-phase, no intra-phase edge required.)

#### T33: Wire F5/F6/F7/F8 into PanelView/MainWindow

**What**: Connect the copy (F5), move (F6), mkdir (F7), delete (F8) key/menu actions in `PanelView`/`MainWindow` to the dialogs built in Phase 5, including error display (FO-15) from `FileSystemServiceImpl`.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift` (extend)
**Depends on**: T21, T24, T26, T30, T32
**Reuses**: None (integration wiring)
**Requirement**: FO-01, FO-02, FO-10, FO-12, FO-15

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] F5/F6/F7/F8 open the correct dialog for the current selection
- [x] A failed operation shows the specific file + reason (FO-15)
- [ ] XCUITest covers the full copy, move, mkdir, delete flows end-to-end from key press to filesystem result - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build && swift test` gate used instead per batch instructions. The dispatch/formatting logic (`PanelView.makeCopyMoveDialog`, `.makeMkdirDialog`, `.makeDeleteDialog`, `.fo15Message`) is unit-tested in `PanelViewFileOperationsTests`; `PanelView.body`'s F5/F6/F7/F8 key binding and sheet presentation are thin declarative glue over those functions, with no additional testable logic.

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): wire F5/F6/F7/F8 file operations into PanelView`

---

### Phase 7: File Viewer

```
T34 → T35
T34 → T37
T35 → T37
T36 → T38
T37 → T38
```

#### T34: ViewerServiceImpl - text/hex chunked loading

**What**: Implement `load(_:)` for text and hex modes with chunked reading so files up to 100MB do not freeze the UI.
**Where**: `Sources/MCGuiMacOS/Viewer/ViewerServiceImpl.swift`
**Depends on**: T7
**Reuses**: `src/McGui.Infrastructure.macOS/MacViewerService.cs`
**Requirement**: FV-02, FV-04, FV-07, FV-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Text mode loads incrementally without blocking the main actor
- [x] Hex mode produces byte chunks suitable for `HexView` (T36)
- [x] Integration tests cover: small text file, 100MB file load time/responsiveness, unreadable file error (FV-08)

**Tests**: integration
**Gate**: full

**Commit**: `feat(macos): implement ViewerServiceImpl text/hex chunked loading`

---

#### T35: ViewerServiceImpl - image loading, navigation, search

**What**: Implement image loading (`NSImage`), `nextFile()`/`previousFile()` navigation within the panel, and text search.
**Where**: `Sources/MCGuiMacOS/Viewer/ViewerServiceImpl.swift` (extend)
**Depends on**: T34
**Reuses**: `src/McGui.Infrastructure.macOS/MacViewerService.cs`
**Requirement**: FV-03, FV-05, FV-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Image files load as `NSImage`
- [x] `nextFile`/`previousFile` cycle through the panel's file list, wrapping or stopping at bounds per design
- [x] `search(_:)` returns match ranges for text content
- [x] Integration tests cover: image load, next/previous at list boundaries, search with 0/1/N matches

**Tests**: integration
**Gate**: full

**Commit**: `feat(macos): add ViewerServiceImpl image loading, file navigation, and search`

---

#### T36: HexView component

**What**: Build a virtualized custom SwiftUI hex/ASCII view, with the byte→hex/ASCII formatting extracted as a pure, unit-testable function.
**Where**: `Sources/MCGuiUI/Components/HexView.swift`
**Depends on**: T5
**Reuses**: None (no native hex view; per design.md AD/Tech Decisions)
**Requirement**: FV-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Renders offset/hex/ASCII columns for a byte chunk
- [x] Virtualizes rendering so large files don't allocate all rows at once
- [x] Unit tests cover the formatting function: standard 16-byte row, partial last row, non-printable-byte ASCII fallback (`.`)

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add virtualized HexView component`

---

#### T37: ViewerViewModel

**What**: Port the viewer ViewModel: mode switching (text/image/hex), search state, scroll position, next/previous wiring.
**Where**: `Sources/MCGuiUI/ViewModels/ViewerViewModel.swift`
**Depends on**: T34, T35
**Reuses**: `src/McGui.App/ViewModels/ViewerViewModel.cs`
**Requirement**: FV-01, FV-02, FV-03, FV-04, FV-05, FV-06, FV-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Mode switches update displayed content without reloading from disk when avoidable
- [x] Error state surfaces FV-08 failures
- [x] Unit tests cover mode switching, search-triggers-scroll, error propagation

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add ViewerViewModel with mode switching and search`

---

#### T38: ViewerWindow

**What**: Build the viewer window: toolbar, mode tabs (Text/Image/Hex), search bar, status bar, F3 key binding, Tab/Shift+Tab navigation.
**Where**: `Sources/MCGuiUI/Views/ViewerWindow.swift`
**Depends on**: T37, T36
**Reuses**: None (new SwiftUI view; layout ported from existing Avalonia `ViewerWindow.axaml` for structure reference)
**Requirement**: FV-01, FV-05, FV-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] F3 on a selected file opens the viewer in the correct mode - **PARTIAL**: `ViewerWindow.load(initialURL)` (via its injected `ViewerViewModel`) always displays the correct mode for whatever file it's given, and F3 is bound within the window itself (to close, see the file's SPEC_DEVIATION - spec.md/design.md don't define an in-viewer F3 action). Constructing and presenting `ViewerWindow` when F3 is pressed on a panel selection, and supplying the panel's file list to the underlying `ViewerServiceImpl.setFileList(_:)` (concrete-type-only, unreachable from `MCGuiUI`), is wiring that belongs to a future task - out of scope here (`Where` is `ViewerWindow.swift` only).
- [x] Tab/Shift+Tab move to next/previous file in the panel (calls `ViewerViewModel.next()`/`.previous()`, tested at the ViewModel layer in T37)
- [x] Cmd+F focuses the search bar
- [ ] XCUITest covers: F3 opens viewer, mode tab switch, Tab navigation, search finds and highlights a match - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build && swift test` gate used instead per batch instructions. Mode switching, navigation, and search logic are unit-tested in `ViewerViewModelTests` (T37); `ViewerWindow.body`'s toolbar/search bar/key bindings are thin declarative glue over `ViewerViewModel`, with no additional testable logic (mirrors T33's `PanelView` precedent).

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add ViewerWindow with mode tabs, search, and F3 binding`

---

### Phase 8: Text Editor

```
T39 → T40
T40 → T41
T41 → T42
T40 → T43
T42 → T43
```

#### T39: EditorServiceImpl

**What**: Implement `EditorService` wrapping `NSTextView` via `NSViewRepresentable` with TextKit 2, `open`/`save`/`close`.
**Where**: `Sources/MCGuiMacOS/Editor/EditorServiceImpl.swift`
**Depends on**: T7
**Reuses**: `src/McGui.Infrastructure.macOS/MacEditorService.cs`
**Requirement**: ED-01, ED-02, ED-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `open(_:)` loads content into `EditorDocumentState` with detected encoding
- [x] `save(_:)` writes content back to disk
- [x] Integration tests cover: load+save round-trip, non-UTF8 encoding detection, save-to-read-only-path error

**Tests**: integration
**Gate**: full

**Commit**: `feat(macos): implement EditorServiceImpl with NSTextView load/save`

---

#### T40: EditorWindowViewModel

**What**: Port dirty-tracking and save-flow ViewModel for the editor.
**Where**: `Sources/MCGuiUI/ViewModels/EditorWindowViewModel.swift`
**Depends on**: T39
**Reuses**: `src/McGui.App/ViewModels/EditorWindowViewModel.cs`, `src/McGui.App/ViewModels/EditorTabViewModel.cs`
**Requirement**: ED-03, ED-05, ED-06, ED-07, ED-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Editing content sets `isDirty`; saving clears it
- [x] Close-with-unsaved-changes triggers the save-prompt flow (delegated to T41/T42)
- [x] Unit tests cover: dirty on edit, clean after save, close with no changes skips prompt

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add EditorWindowViewModel with dirty tracking`

---

#### T41: SaveChangesDialogViewModel

**What**: Port the Save/Don't Save/Cancel prompt ViewModel.
**Where**: `Sources/MCGuiUI/ViewModels/SaveChangesDialogViewModel.swift`
**Depends on**: T40
**Reuses**: `src/McGui.App/ViewModels/SaveChangesDialogViewModel.cs`, `src/McGui.App/ViewModels/ISaveChangesPrompt.cs`
**Requirement**: ED-05, ED-06, ED-07, ED-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Exposes the 3 actions and reports the chosen outcome to the caller
- [x] Unit tests cover each of the 3 outcomes

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add SaveChangesDialogViewModel`

---

#### T42: SaveChangesDialog view

**What**: Build the Save/Don't Save/Cancel dialog UI.
**Where**: `Sources/MCGuiUI/Views/SaveChangesDialog.swift`
**Depends on**: T41
**Reuses**: None (new SwiftUI view)
**Requirement**: ED-05, ED-06, ED-07, ED-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] All 3 buttons present and wired to the ViewModel action
- [ ] XCUITest covers: closing a dirty editor triggers the prompt, each of the 3 buttons produces the correct outcome (saved/discarded/still-open) - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build && swift test` gate used instead per batch instructions. The 3 outcomes this view's buttons invoke are unit-tested in `SaveChangesDialogViewModelTests` (T41); `SaveChangesDialog` itself is a thin declarative binding with no additional testable logic (mirrors T28's `ConflictDialog` precedent).

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add SaveChangesDialog view`

---

#### T43: EditorWindow

**What**: Build the editor window: toolbar, `NSTextView` wrapper, cut/copy/paste/undo/redo/select-all, find/replace, F4 key binding, Cmd+S save.
**Where**: `Sources/MCGuiUI/Views/EditorWindow.swift`
**Depends on**: T40, T42
**Reuses**: None (new SwiftUI view; layout ported from existing Avalonia `EditorWindow.axaml` for structure reference)
**Requirement**: ED-01, ED-09, ED-10

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] F4 on a selected text file opens the editor with syntax-highlighted content - **PARTIAL**: `EditorWindow` always displays whatever `EditorWindowViewModel`/`EditorDocumentState` content it's given (correct file), via a monospaced `NSTextView` - full per-token syntax highlighting is a documented design.md risk with an explicit fallback ("basic coloring if needed", Risks & Concerns), used here. Constructing and presenting `EditorWindow` when F4 is pressed on a panel selection is cross-target wiring belonging to a future task (MCGuiApp, Phase 11) - out of scope here (`Where` is `EditorWindow.swift` only), mirrors T38's `ViewerWindow`/F3 precedent.
- [x] Cmd+S saves; Cmd+F / Cmd+Option+F open find/replace
- [ ] XCUITest covers: F4 opens editor, edit+save round-trip, find/replace performs a replacement, close-with-unsaved-changes shows the save prompt - **DEFERRED**: no Xcode project/scheme exists yet in this pure-SPM setup; `swift build && swift test` gate used instead per batch instructions. The find/replace logic this view's buttons invoke (`EditorWindow.nextMatch`, `.replaceAll`) is unit-tested in `EditorWindowTests`; the save/dirty/close flow is unit-tested in `EditorWindowViewModelTests` (T40) and `SaveChangesDialogViewModelTests` (T41); `EditorWindow.body` and `EditorTextView` are thin declarative/AppKit-bridging glue over those, with no additional testable logic (mirrors T38's `ViewerWindow` precedent).

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add EditorWindow with toolbar, find/replace, and F4 binding`

---

### Phase 9: Keyboard Navigation & Commands

```
T44 → T45
```

#### T44: KeyboardShortcuts

**What**: Declare all F-key and Cmd+ shortcuts (F3-F8, Cmd+1/2/3/4, Cmd+., Cmd+Up/[/], Enter, Escape) using SwiftUI `.keyboardShortcut`.
**Where**: `Sources/MCGuiUI/Commands/KeyboardShortcuts.swift`
**Depends on**: T21
**Reuses**: `src/McGui.App/EditorSearch.cs` (key-combo parsing reference), `src/McGui.App/McMenuDefinitions.cs` (shortcut-to-action mapping reference)
**Requirement**: KN-07, KN-08, KN-09, KN-10, KN-11, KN-12

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Every shortcut in KN-07..KN-12 is declared and routes to the correct action
- [ ] XCUITest covers each shortcut firing its bound action once

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add KeyboardShortcuts for F-keys and Cmd+ combos`

---

#### T45: PanelCommands

**What**: Wire Tab (focus switch), arrow keys, Shift+Arrow, Cmd+Arrow, Space, Insert into `PanelView` via `SelectionService`.
**Where**: `Sources/MCGuiUI/Commands/PanelCommands.swift`
**Depends on**: T44, T9
**Reuses**: None (new wiring; logic in T9)
**Requirement**: KN-01, KN-02, KN-03, KN-04, KN-05, KN-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Tab switches active panel; arrows move selection; Shift+Arrow extends range; Cmd+Arrow jumps to first/last; Space toggles; Insert toggles + moves down
- [ ] XCUITest covers each of the 6 KN-01..06 behaviors

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): wire PanelCommands for Tab/arrow/space/insert navigation`

---

### Phase 10: Theme Support

```
T46 → T47
```

#### T46: ThemePreference

**What**: Port the System/Light/Dark theme preference with `@AppStorage` persistence.
**Where**: `Sources/MCGuiUI/ViewModels/ThemePreference.swift`
**Depends on**: T1
**Reuses**: `src/McGui.App/ViewModels/ThemePreference.cs`
**Requirement**: TH-01, TH-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Defaults to System; persists across relaunch via `@AppStorage`
- [ ] Unit tests cover default value and persistence round-trip (via `UserDefaults` suite injection)

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add ThemePreference with @AppStorage persistence`

---

#### T47: Theme submenu wiring

**What**: Add the Light/Dark/Follow-System menu options and apply `.preferredColorScheme` live across all views by injecting the preference into `MainWindow`.
**Where**: `Sources/MCGuiUI/Views/ThemeMenu.swift`
**Depends on**: T46, T22
**Reuses**: None (new wiring)
**Requirement**: TH-02, TH-03, TH-04, TH-05

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Selecting each theme option updates the UI immediately without restart
- [ ] XCUITest covers: switch to Light, switch to Dark, switch to Follow System, verify visual state changes

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): wire theme submenu with live color-scheme updates`

---

### Phase 11: Menu Bar & App Entry

```
T48 → T50
T49 → T50
```

#### T48: AppCommands

**What**: Build the `Commands` builder for the full native menu bar (App, File, Edit, View, Go, Window, Help) per MB-01..MB-07, with visible keyboard shortcuts.
**Where**: `Sources/MCGuiUI/Commands/AppCommands.swift`
**Depends on**: T44, T47
**Reuses**: `src/McGui.App/McMenuDefinitions.cs`
**Requirement**: MB-01, MB-02, MB-03, MB-04, MB-05, MB-06, MB-07

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] All 7 top-level menus present with the exact items listed in spec MB-02..MB-06
- [ ] Every menu item shows its keyboard shortcut
- [ ] XCUITest covers: each menu is present, a sampled item from each menu triggers its action

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add AppCommands native menu bar (File/Edit/View/Go/Window/Help)`

---

#### T49: WindowManager

**What**: Build window lifecycle management for main/viewer/editor/dialog windows.
**Where**: `Sources/MCGuiApp/WindowManager.swift`
**Depends on**: T38, T43, T22
**Reuses**: None (new SwiftUI app structure per design.md)
**Requirement**: MB-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `showMainWindow`, `showViewer(for:panel:)`, `showEditor(for:)`, `showDialog(content:)` implemented
- [ ] Window menu (Minimize/Zoom/Viewer/Editor) operates on the correct window instances

**Tests**: none
**Gate**: build

**Commit**: `feat(app): add WindowManager for main/viewer/editor/dialog windows`

---

#### T50: AppEntry

**What**: Build the `App` entry point wiring `MainWindow`, `AppCommands`, and `WindowManager` together; app launches to a fully functional dual-pane window.
**Where**: `Sources/MCGuiApp/AppEntry.swift`
**Depends on**: T48, T49
**Reuses**: None (new SwiftUI app structure per design.md)
**Requirement**: SWIFT-05, MB-01

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `swift run` launches the app to a visible dual-pane window with menu bar
- [ ] XCUITest covers: app launch, main window visible, menu bar present

**Tests**: e2e
**Gate**: build

**Commit**: `feat(app): add AppEntry wiring MainWindow, AppCommands, and WindowManager`

---

### Phase 12: Volume Listing & Search/Filter (P2)

```
T51
T52
```

(No intra-phase dependencies - T51, T52 are independent of each other; execute in numeric order.)

#### T51: Volume list in Go menu + sidebar + mount/unmount updates

**What**: Display mounted volumes in the Go menu and a sidebar/toolbar location; navigate to a volume's root on selection; update on `NSWorkspace` mount/unmount notifications.
**Where**: `Sources/MCGuiUI/Views/MainWindow.swift` (extend, volume section)
**Depends on**: T14, T48
**Reuses**: `src/McGui.Infrastructure.macOS/VolumeLocator.cs`
**Requirement**: VL-01, VL-02, VL-03, VL-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Volumes appear in both the Go menu and sidebar/toolbar
- [ ] Selecting a volume navigates the active panel to its root
- [ ] `NSWorkspace.didMountNotification`/`didUnmountNotification` refresh the list
- [ ] XCUITest covers: select a volume from Go menu navigates correctly (mount/unmount tested manually per design.md Risk - simulated notification injected in test where feasible)

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add volume listing in Go menu and sidebar with mount/unmount updates`

---

#### T52: Live filename filter in panel

**What**: Add case-insensitive, substring-anywhere live filtering of panel entries as the user types; Escape clears the filter.
**Where**: `Sources/MCGuiUI/ViewModels/PanelViewModel.swift` (extend)
**Depends on**: T17
**Reuses**: None (new logic; no C# equivalent exists)
**Requirement**: SF-01, SF-02, SF-03, SF-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Typing filters `entries` to matching names (case-insensitive substring)
- [ ] Escape clears the filter and restores the full list
- [ ] Unit tests cover: no match, partial match, case-insensitivity, Escape-clears

**Tests**: unit
**Gate**: quick

**Commit**: `feat(ui): add live filename filter to PanelViewModel`

---

### Phase 13: Bookmarks (P3)

```
T53 → T54
```

#### T53: BookmarkStore

**What**: Build a `Bookmark` model + JSON-persisted store (add/remove/list), mirroring the `PathHistoryStoreImpl` persistence pattern.
**Where**: `Sources/MCGuiMacOS/Bookmarks/BookmarkStore.swift`
**Depends on**: T16
**Reuses**: `src/McGui.Infrastructure.macOS/MacPathHistoryStore.cs` (JSON persistence pattern only - no bookmark feature exists in the C# app)
**Requirement**: BM-01, BM-03, BM-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Add/remove/list persist to `~/Library/Application Support/MCGui/bookmarks.json`
- [ ] Integration tests cover: add+persist+reload, remove, corrupt-file recovery to empty list

**Tests**: integration
**Gate**: full

**Commit**: `feat(macos): add BookmarkStore with JSON persistence`

---

#### T54: Bookmarks UI

**What**: Add a bookmarks sidebar/menu with add-current-directory (Cmd+D), navigate-on-select, and remove.
**Where**: `Sources/MCGuiUI/Views/BookmarksView.swift`
**Depends on**: T53, T48
**Reuses**: None (new SwiftUI view; no C# equivalent exists)
**Requirement**: BM-01, BM-02, BM-03, BM-04

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Cmd+D adds the active panel's current directory
- [ ] Selecting a bookmark navigates the active panel there; a remove control deletes it
- [ ] XCUITest covers: add via Cmd+D, navigate via selection, remove, persistence across relaunch

**Tests**: e2e
**Gate**: build

**Commit**: `feat(ui): add Bookmarks sidebar/menu with add/remove/navigate`

---

## Phase Execution Map

Summary of task ranges per phase (see **Task Breakdown** above for the authoritative per-phase dependency diagrams):

| Phase | Name | Tasks |
| ----- | ---- | ----- |
| 1 | Foundation | T1, T2, T3, T4, T5, T6, T7, T8 |
| 2 | Core Services | T9, T10, T11 |
| 3 | macOS Infrastructure | T12, T13, T14, T15, T16 |
| 4 | Panel UI | T17, T18, T19, T20, T21, T22 |
| 5 | Operation Dialogs | T23, T24, T25, T26, T27, T28, T29, T30, T31, T32 |
| 6 | Wire Operations | T33 |
| 7 | Viewer | T34, T35, T36, T37, T38 |
| 8 | Editor | T39, T40, T41, T42, T43 |
| 9 | Keyboard | T44, T45 |
| 10 | Theme | T46, T47 |
| 11 | Menu Bar / App | T48, T49, T50 |
| 12 | Volume / Filter (P2) | T51, T52 |
| 13 | Bookmarks (P3) | T53, T54 |

Execution is strictly sequential - there is no intra-phase parallelism. A single agent (or batch worker) works one task at a time, in order.

---

## Task Granularity Check

| Task | Scope | Status |
| ---- | ----- | ------ |
| T1 | 1 file (Package.swift) | ✅ Granular |
| T2 | 1 file (FileEntry + tightly-coupled FileType/FilePermissions) | ✅ Granular |
| T3 | 1 file (3 tightly-coupled panel models) | ✅ Granular |
| T4 | 1 file (5 tightly-coupled operation models) | ✅ Granular |
| T5 | 1 file (4 tightly-coupled editor/viewer models) | ✅ Granular |
| T6 | 1 file, 1 protocol | ✅ Granular |
| T7 | 1 file, 4 short protocols | ✅ Granular |
| T8 | 1 file, 1 test | ✅ Granular |
| T9 | 1 file, 1 service | ✅ Granular |
| T10 | 1 file, 1 service | ✅ Granular |
| T11 | 1 file, 1 service | ✅ Granular |
| T12 | 1 file (2 methods) | ✅ Granular |
| T13 | 1 file, extends T12 (2 methods) | ✅ Granular |
| T14 | 1 file, extends T12 (1 method) | ✅ Granular |
| T15 | 1 file, 1 service | ✅ Granular |
| T16 | 1 file, 1 service | ✅ Granular |
| T17 | 1 file, 1 ViewModel | ✅ Granular |
| T18 | 1 file, 1 ViewModel | ✅ Granular |
| T19 | 1 file, 5 small cohesive components | ✅ Granular (same-file, cohesive) |
| T20 | 1 file, 1 view | ✅ Granular |
| T21 | 1 file, 1 view | ✅ Granular |
| T22 | 1 file, 1 view | ✅ Granular |
| T23 | 1 file, 1 ViewModel | ✅ Granular |
| T24 | 1 file, 1 view | ✅ Granular |
| T25 | 1 file, 1 ViewModel | ✅ Granular |
| T26 | 1 file, 1 view | ✅ Granular |
| T27 | 1 file, 1 ViewModel | ✅ Granular |
| T28 | 1 file, 1 view | ✅ Granular |
| T29 | 1 file, 1 ViewModel | ✅ Granular |
| T30 | 1 file, 1 view | ✅ Granular |
| T31 | 1 file, 1 ViewModel | ✅ Granular |
| T32 | 1 file, 1 view | ✅ Granular |
| T33 | 1 file, extends T21 (integration wiring) | ✅ Granular |
| T34 | 1 file, chunked load | ✅ Granular |
| T35 | 1 file, extends T34 | ✅ Granular |
| T36 | 1 file, 1 component | ✅ Granular |
| T37 | 1 file, 1 ViewModel | ✅ Granular |
| T38 | 1 file, 1 window | ✅ Granular |
| T39 | 1 file, 1 service | ✅ Granular |
| T40 | 1 file, 1 ViewModel | ✅ Granular |
| T41 | 1 file, 1 ViewModel | ✅ Granular |
| T42 | 1 file, 1 view | ✅ Granular |
| T43 | 1 file, 1 window | ✅ Granular |
| T44 | 1 file, shortcut declarations | ✅ Granular |
| T45 | 1 file, wiring | ✅ Granular |
| T46 | 1 file, 1 model | ✅ Granular |
| T47 | 1 file, wiring | ✅ Granular |
| T48 | 1 file, 1 Commands builder | ✅ Granular |
| T49 | 1 file, 1 manager | ✅ Granular |
| T50 | 1 file, entry point | ✅ Granular |
| T51 | 1 file, wiring | ✅ Granular |
| T52 | 1 file, extends T17 | ✅ Granular |
| T53 | 1 file, 1 store | ✅ Granular |
| T54 | 1 file, 1 view | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| ---- | ----------------------- | -------------- | ------ |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T1 | T1 → T3 | ✅ Match |
| T4 | T1 | T1 → T4 | ✅ Match |
| T5 | T1 | T1 → T5 | ✅ Match |
| T6 | T2, T3, T4 | T2→T6, T3→T6, T4→T6 | ✅ Match |
| T7 | T4, T5 | T4→T7, T5→T7 | ✅ Match |
| T8 | T6, T7 | T6→T8, T7→T8 | ✅ Match |
| T13 | T12 (+ T11 cross-phase) | T12→T13 | ✅ Match |
| T14 | T12 | T12→T14 | ✅ Match |
| T18 | T17 (+ cross-phase) | T17→T18 | ✅ Match |
| T20 | T19 (+ T2 cross-phase) | T19→T20 | ✅ Match |
| T21 | T17, T20 | T17→T21, T20→T21 | ✅ Match |
| T22 | T18, T21 | T18→T22, T21→T22 | ✅ Match |
| T24 | T23 | T23→T24 | ✅ Match |
| T26 | T25 | T25→T26 | ✅ Match |
| T28 | T27 | T27→T28 | ✅ Match |
| T29 | T27 (+ T11 cross-phase) | T27→T29 | ✅ Match |
| T30 | T29 | T29→T30 | ✅ Match |
| T32 | T31 | T31→T32 | ✅ Match |
| T35 | T34 | T34→T35 | ✅ Match |
| T37 | T34, T35 | T34→T37, T35→T37 | ✅ Match |
| T38 | T37, T36 | T37→T38, T36→T38 | ✅ Match |
| T40 | T39 | T39→T40 | ✅ Match |
| T41 | T40 | T40→T41 | ✅ Match |
| T42 | T41 | T41→T42 | ✅ Match |
| T43 | T40, T42 | T40→T43, T42→T43 | ✅ Match |
| T45 | T44 (+ T9 cross-phase) | T44→T45 | ✅ Match |
| T47 | T46 (+ T22 cross-phase) | T46→T47 | ✅ Match |
| T50 | T48, T49 | T48→T50, T49→T50 | ✅ Match |
| T54 | T53 (+ T48 cross-phase) | T53→T54 | ✅ Match |

All other tasks (T1, T9-T11, T12, T15-T17, T19, T23, T25, T27, T31, T33-T34, T36, T39, T44, T46, T48-T49, T51-T53) either have no dependencies, or their `Depends on` entries all point to earlier phases (verified backward-only in the Task Breakdown above) - no intra-phase diagram arrow required since diagram parity applies only within the same phase.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| ---- | ---------------------------- | ---------------- | ---------- | ------ |
| T1 | Package manifest | none | none | ✅ OK |
| T2-T5 | Domain Models | unit | unit | ✅ OK |
| T6-T7 | Protocols | none | none | ✅ OK |
| T8 | Smoke test | unit | unit | ✅ OK |
| T9-T11 | Core Services | unit | unit | ✅ OK |
| T12-T16 | macOS Service Impls | integration | integration | ✅ OK |
| T17-T18 | ViewModels | unit | unit | ✅ OK |
| T19-T20 | Presentational Components | none | none | ✅ OK |
| T21-T22 | Interactive Views | e2e | e2e | ✅ OK |
| T23, T25, T27, T29, T31 | ViewModels | unit | unit | ✅ OK |
| T24, T26, T28, T30, T32 | Interactive Views | e2e | e2e | ✅ OK |
| T33 | Interactive Views (wiring) | e2e | e2e | ✅ OK |
| T34-T35 | macOS Service Impls | integration | integration | ✅ OK |
| T36 | Component w/ embedded formatting logic | unit | unit | ✅ OK |
| T37 | ViewModel | unit | unit | ✅ OK |
| T38 | Interactive View | e2e | e2e | ✅ OK |
| T39 | macOS Service Impl | integration | integration | ✅ OK |
| T40-T41 | ViewModels | unit | unit | ✅ OK |
| T42-T43 | Interactive Views | e2e | e2e | ✅ OK |
| T44-T45 | Commands (interactive) | e2e | e2e | ✅ OK |
| T46 | ViewModel-like model | unit | unit | ✅ OK |
| T47 | Interactive wiring | e2e | e2e | ✅ OK |
| T48 | Commands (interactive) | e2e | e2e | ✅ OK |
| T49 | App Entry / WindowManager | none (no window shown yet standalone) | none | ✅ OK |
| T50 | App Entry | e2e | e2e | ✅ OK |
| T51 | Interactive wiring | e2e | e2e | ✅ OK |
| T52 | ViewModel (extend) | unit | unit | ✅ OK |
| T53 | macOS Service Impl (persistence) | integration | integration | ✅ OK |
| T54 | Interactive View | e2e | e2e | ✅ OK |

No violations. `Tests: none` occurs only for Package config (T1), pure protocols (T6-T7), pure-presentational components (T19-T20), and `WindowManager` before any window logic lands on it (T49) - all layers the matrix explicitly marks `none`.

---

## Tools for Execution

All 54 tasks use standard Xcode/SPM toolchain only - no MCP or skill beyond `tlc-spec-driven` itself is required (Foundation, AppKit, SwiftUI, Swift Testing, XCUITest are all first-party). If an unfamiliar API surfaces during a task (e.g. TextKit 2 syntax highlighting specifics), follow the skill's Knowledge Verification Chain: codebase → project docs → Context7 MCP (resolve `swift`/`apple` docs if available) → web search → flag as uncertain. Do not fabricate API names.
