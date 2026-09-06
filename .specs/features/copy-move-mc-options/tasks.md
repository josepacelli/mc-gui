# Copy/Move MC Options Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

**This feature was specified and designed ahead of implementation** (user asked to prepare it now, execute later). Before starting Execute, re-read `spec.md` and `design.md` in full - do not assume the context from authoring this file is still loaded.

---

**Design**: `.specs/features/copy-move-mc-options/design.md`
**Status**: Approved

---

## Test Coverage Matrix

> Generated from codebase sampling. Guidelines found: none (`AGENTS.md`/`CONTRIBUTING.md` absent) - repo's own existing tests set the floor. `McGui.Core.Tests` and `McGui.Infrastructure.macOS.Tests` use plain xUnit with no mocking framework - the Infrastructure layer is tested against a real temp directory (`TempDirectoryFixture`), not mocks. `McGui.App.Tests` has no `Avalonia.Headless`, so XAML-facing changes are tested via text/regex assertion on the `.axaml` file content (established pattern, see `MainWindowMenuBarStructureTests`/`MainWindowNativeMenuTests` from the `macos-native-chrome` feature) and plain-C# ViewModel properties are tested directly.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Core model/enum (`FileConflictResolution`, `CopyMoveOptions`) | unit | 1:1 to spec ACs | `tests/McGui.Core.Tests/**/*.cs` | `dotnet test tests/McGui.Core.Tests` |
| Infrastructure file ops (`MacFileSystemService`) | unit (real temp-dir I/O, no mocks - existing pattern) | Every spec AC + listed edge case exercised on a real filesystem | `tests/McGui.Infrastructure.macOS.Tests/**/*.cs` | `dotnet test tests/McGui.Infrastructure.macOS.Tests` |
| App ViewModel property (plain C#) | unit | 1:1 to spec AC per new property/default | `tests/McGui.App.Tests/ViewModels/*Tests.cs` | `dotnet test tests/McGui.App.Tests` |
| App XAML structure (checkbox/button presence, binding) | unit (text/regex on file content) | Every spec AC about markup presence has an assertion | `tests/McGui.App.Tests/*.cs` | `dotnet test tests/McGui.App.Tests` |
| `CopyDirectoryRecursively` cross-volume fallback path (Move) | none - documented gap | Same-volume CI/dev environment cannot force `Directory.Move` to fail and trigger this fallback; correctness verified by code sharing the already-tested `CopySingleFile` helper, not by a dedicated test | `src/McGui.Infrastructure.macOS/MacFileSystemService.cs` | build gate + code inspection during Verifier round only |

## Gate Check Commands

> Generated from codebase (`McGui.sln`, `dotnet test` is the sole test runner; no separate lint/format script found).

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After a task touching only one test project | `dotnet test tests/<ProjectName>` (project matching the layer touched) |
| Full | After phase completion, or a task touching more than one project | `dotnet build McGui.sln && dotnet test McGui.sln` |
| Build | Config/markup-only task with no new test (per matrix "none" row) | `dotnet build McGui.sln` |

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins, and tasks within a phase execute in order.

### Phase 1: P1 - "Update" conflict resolution

```
T1 → T2
T1 → T3
```

T2 and T3 both depend only on T1 (not on each other) - they execute in the order T2 then T3 within the phase, but neither blocks the other.

### Phase 2: Foundation - CopyMoveOptions plumbing (needed by P2 and P3, not by P1)

```
T4 → T5
```

### Phase 3: P2 - Preserve attributes

```
T5 → T6
T5 → T7
```

T6 and T7 both depend on T5 (from Phase 2), not on each other - they execute in the order T6 then T7 within the phase.

### Phase 4: P3 - Follow symlinks

```
T6 → T8
T7 → T9
```

### Phase 5: Cross-cutting correctness

```
T9 → T10
```

---

## Task Breakdown

### T1: Add `Update` value to `FileConflictResolution`

**What**: Add `Update` to the `FileConflictResolution` enum, between `Rename` and `Abort`.
**Where**: `src/McGui.Core/Models/FileConflictResolution.cs`
**Depends on**: None
**Reuses**: enum already exists, only grows one value
**Requirement**: CPMV-04

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `FileConflictResolution` has 5 values: `Overwrite, Skip, Rename, Update, Abort`
- [ ] `dotnet build McGui.sln` succeeds (existing switch statements still compile - they all have a `default:` fallthrough today)

**Tests**: none (single enum value, no branching logic yet - covered indirectly by T2/T3's tests)
**Gate**: build

**Commit**: `feat(core): add Update value to FileConflictResolution`

---

### T2: Expose "Update" in the conflict prompt dialog

**What**: Add an `Update` `[RelayCommand]` to `ConflictDialogViewModel` (completing with `FileConflictResolution.Update`) and a matching `<Button Content="Update" Command="{Binding UpdateCommand}" />` in `ConflictDialog.axaml`, between "Rename" and "Overwrite".
**Where**: `src/McGui.App/ViewModels/ConflictDialogViewModel.cs`, `src/McGui.App/Views/ConflictDialog.axaml`, `tests/McGui.App.Tests/ViewModels/ConflictDialogViewModelTests.cs` (extend)
**Depends on**: T1
**Reuses**: `Complete(...)` already existing, same pattern as `Overwrite()`/`Skip()`/`Rename()`/`Abort()`
**Requirement**: CPMV-04

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `UpdateCommand` exists and completes the dialog with `FileConflictResolution.Update` (respecting `ApplyToAll` like the other commands)
- [ ] `ConflictDialog.axaml` shows the "Update" button between "Rename" and "Overwrite"
- [ ] Existing 4 buttons/commands unchanged
- [ ] Gate check passes: `dotnet test tests/McGui.App.Tests`
- [ ] Test count: existing `ConflictDialogViewModelTests` facts + 1 new, all passing (no silent deletions)

**Tests**: unit
**Gate**: quick

**Commit**: `feat(app): add Update option to the conflict prompt dialog`

---

### T3: Handle `Update` in `MacFileSystemService`'s conflict switch

**What**: Add `case FileConflictResolution.Update:` to the conflict `switch` in both `ExecuteCopy` and `ExecuteMove` - compare `entry.ModifiedUtc` (source) against `File.GetLastWriteTimeUtc(destinationPath)` (destination); if source is newer, fall through to the same path as `Overwrite`; otherwise, the same path as `Skip`. For a directory-level conflict during `ExecuteMove` (Move works on top-level entries, which can be directories), treat `Update` the same as `Overwrite` (see design.md Error Handling Strategy - directory mtime comparison isn't meaningful without partial-merge support, which is out of scope).
**Where**: `src/McGui.Infrastructure.macOS/MacFileSystemService.cs`, `tests/McGui.Infrastructure.macOS.Tests/MacFileSystemServiceTests.cs` (extend)
**Depends on**: T1
**Reuses**: existing `switch (resolution)` blocks in `ExecuteCopy`/`ExecuteMove`, `TempDirectoryFixture` test pattern
**Requirement**: CPMV-01, CPMV-02, CPMV-03

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `CopyAsync`/`MoveAsync` with `resolveConflict` returning `Update`: source newer than destination → destination file is overwritten with source content
- [ ] Source not newer (equal or older) → destination file is left untouched, no error, entry counted as processed
- [ ] `ApplyToAll` with `Update` (already wired via `ConflictPromptResult`) applies the same per-file newer-check to every subsequent conflict in the same operation, without re-prompting
- [ ] Directory-level conflict in `ExecuteMove` with `Update` behaves like `Overwrite` (whole-directory replace)
- [ ] Gate check passes: `dotnet test tests/McGui.Infrastructure.macOS.Tests`
- [ ] Test count: existing facts + at least 3 new (newer-overwrites, older-skips, directory-conflict-behaves-like-overwrite), all passing (no silent deletions)

**Tests**: unit (real temp-dir I/O)
**Gate**: quick

**Commit**: `feat(infra): overwrite only-if-newer for the Update conflict resolution`

---

### T4: Add `CopyMoveOptions` model

**What**: Add the `CopyMoveOptions` record (`PreserveAttributes`, `FollowSymlinks`) with a static `Default` (`PreserveAttributes: false, FollowSymlinks: true`, matching spec defaults).
**Where**: `src/McGui.Core/Models/CopyMoveOptions.cs` (new)
**Depends on**: None
**Reuses**: same `sealed record` pattern as `CopyMovePlan`/`OperationProgress`
**Requirement**: CPMV-05, CPMV-09

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `CopyMoveOptions(bool PreserveAttributes, bool FollowSymlinks)` record exists
- [ ] `CopyMoveOptions.Default` has `PreserveAttributes = false`, `FollowSymlinks = true`
- [ ] Gate check passes: `dotnet test tests/McGui.Core.Tests`
- [ ] Test count: 1 new fact asserting `Default`'s values, all passing

**Tests**: unit
**Gate**: quick

**Commit**: `feat(core): add CopyMoveOptions model with spec-defined defaults`

---

### T5: Thread `CopyMoveOptions` through `IFileSystemService.CopyAsync`/`MoveAsync`

**What**: Add a `CopyMoveOptions options` parameter to `IFileSystemService.CopyAsync`/`MoveAsync` (right after `plan`). Update the only implementation (`MacFileSystemService`) and the only fake (`FakeFileSystemService`) to match the new signature - `options` is accepted but not yet used by either (that's T7/T9). Update every existing call site (`CopyMoveDialogViewModel.ConfirmAsync` passes `CopyMoveOptions.Default` as a placeholder here - T6/T8 change that line to pass the real UI-bound values; every `MacFileSystemServiceTests`/`CopyMoveDialogViewModelTests` call site passes `CopyMoveOptions.Default`).
**Where**: `src/McGui.Core/Interfaces/IFileSystemService.cs`, `src/McGui.Infrastructure.macOS/MacFileSystemService.cs`, `src/McGui.App/ViewModels/CopyMoveDialogViewModel.cs`, `tests/McGui.App.Tests/Fakes/FakeFileSystemService.cs`, `tests/McGui.Infrastructure.macOS.Tests/MacFileSystemServiceTests.cs`, `tests/McGui.App.Tests/ViewModels/CopyMoveDialogViewModelTests.cs`
**Depends on**: T4
**Reuses**: existing method bodies, unchanged aside from the new parameter being accepted
**Requirement**: CPMV-05, CPMV-09

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `IFileSystemService.CopyAsync`/`MoveAsync` both take `CopyMoveOptions options`
- [ ] `MacFileSystemService`/`FakeFileSystemService` compile against the new signature (options unused for now, no behavior change)
- [ ] `CopyMoveDialogViewModel.ConfirmAsync` passes `CopyMoveOptions.Default` (placeholder, updated in T6/T8)
- [ ] Every existing call site updated - no compile errors anywhere in the solution
- [ ] Gate check passes: `dotnet build McGui.sln && dotnet test McGui.sln`
- [ ] Test count: unchanged from before this task (pure signature/plumbing change, no new behavior, no new tests) - full suite (219 baseline + T1-T4's new tests) still green

**Tests**: none (mechanical signature propagation - behavior tested by T3 already for Update, and by T7/T9 once they consume `options`)
**Gate**: full

**Commit**: `refactor(core,infra,app): thread CopyMoveOptions through copy/move calls`

---

### T6: Expose "Preserve attributes" checkbox

**What**: Add `[ObservableProperty] private bool preserveAttributes = false;` to `CopyMoveDialogViewModel`, a `<CheckBox Content="Preservar atributos" IsChecked="{Binding PreserveAttributes}" />` in `CopyMoveDialog.axaml`, and change `ConfirmAsync`'s `CopyMoveOptions` construction to use `PreserveAttributes` (still `FollowSymlinks: true` literal until T8 wires the second checkbox).
**Where**: `src/McGui.App/ViewModels/CopyMoveDialogViewModel.cs` (modify), `src/McGui.App/Views/CopyMoveDialog.axaml` (modify), `tests/McGui.App.Tests/ViewModels/CopyMoveDialogViewModelTests.cs` (extend)
**Depends on**: T5
**Reuses**: `[ObservableProperty]` pattern already used for `destinationDirectory`/`newName`
**Requirement**: CPMV-07

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `PreserveAttributes` defaults to `false`
- [ ] Checkbox present in `CopyMoveDialog.axaml`, bound to `PreserveAttributes`
- [ ] `ConfirmAsync` passes `PreserveAttributes`'s current value into `CopyMoveOptions`
- [ ] Gate check passes: `dotnet test tests/McGui.App.Tests`
- [ ] Test count: existing facts + 1 new (default is false) + 1 new (structural: checkbox present in XAML), all passing

**Tests**: unit (ViewModel property + text-based XAML structure)
**Gate**: quick

**Commit**: `feat(app): add Preserve attributes checkbox to copy/move dialog`

---

### T7: Preserve attributes during copy (centralize into `CopySingleFile`)

**What**: Introduce `private static void CopySingleFile(FileEntry entry, string destinationPath, CopyMoveOptions options, List<(string,string)> skipped)` in `MacFileSystemService`, replacing the inline `File.Copy(...)` call in `ExecuteCopy`. After copying, if `options.PreserveAttributes`, call `ApplyPreservedAttributes(entry.FullPath, destinationPath, skipped)` - a new helper applying `File.SetUnixFileMode(destinationPath, File.GetUnixFileMode(sourcePath))` and `File.SetLastWriteTimeUtc(destinationPath, entry.ModifiedUtc.UtcDateTime)`, catching `IOException`/`UnauthorizedAccessException` into `skipped` as a warning (not aborting the file's own copy, which already succeeded).
**Where**: `src/McGui.Infrastructure.macOS/MacFileSystemService.cs`, `tests/McGui.Infrastructure.macOS.Tests/MacFileSystemServiceTests.cs` (extend)
**Depends on**: T5
**Reuses**: `skipped` list already threaded through `ExecuteCopy`
**Requirement**: CPMV-05, CPMV-06, CPMV-08

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `CopyAsync` with `PreserveAttributes: true` reproduces source's Unix file mode and `ModifiedUtc` on the destination file
- [ ] `CopyAsync` with `PreserveAttributes: false` leaves destination metadata as the OS/`.NET` default (no explicit attribute call made) - existing tests still pass unchanged
- [ ] A permission failure while applying an attribute is caught and added to `OperationResult.Skipped` with a message, without the file being un-copied or the whole operation aborting
- [ ] Gate check passes: `dotnet test tests/McGui.Infrastructure.macOS.Tests`
- [ ] Test count: existing facts + at least 3 new (mode preserved, timestamp preserved, off-by-default unchanged behavior), all passing

**Tests**: unit (real temp-dir I/O)
**Gate**: quick

**Commit**: `feat(infra): preserve Unix mode and timestamp when PreserveAttributes is set`

---

### T8: Expose "Follow symlinks" checkbox

**What**: Add `[ObservableProperty] private bool followSymlinks = true;` to `CopyMoveDialogViewModel`, a `<CheckBox Content="Seguir links" IsChecked="{Binding FollowSymlinks}" />` in `CopyMoveDialog.axaml`, and change `ConfirmAsync`'s `CopyMoveOptions` construction to use `FollowSymlinks` (replacing the literal `true` from T6).
**Where**: `src/McGui.App/ViewModels/CopyMoveDialogViewModel.cs` (modify), `src/McGui.App/Views/CopyMoveDialog.axaml` (modify), `tests/McGui.App.Tests/ViewModels/CopyMoveDialogViewModelTests.cs` (extend)
**Depends on**: T6
**Reuses**: same `[ObservableProperty]`/checkbox pattern as T6
**Requirement**: CPMV-11

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `FollowSymlinks` defaults to `true`
- [ ] Checkbox present in `CopyMoveDialog.axaml`, bound to `FollowSymlinks`
- [ ] `ConfirmAsync` passes both `PreserveAttributes` and `FollowSymlinks` into `CopyMoveOptions` (no more literals)
- [ ] Gate check passes: `dotnet test tests/McGui.App.Tests`
- [ ] Test count: existing facts + 1 new (default is true) + 1 new (structural: checkbox present), all passing

**Tests**: unit (ViewModel property + text-based XAML structure)
**Gate**: quick

**Commit**: `feat(app): add Follow symlinks checkbox to copy/move dialog`

---

### T9: Symlink gate in `CopySingleFile`

**What**: Extend `CopySingleFile` (from T7): if `entry.IsSymlink && !options.FollowSymlinks`, call `File.CreateSymbolicLink(destinationPath, new FileInfo(entry.FullPath).LinkTarget!)` instead of `File.Copy`. If `entry.IsSymlink && options.FollowSymlinks` and the resolved target does not exist (broken symlink - `!File.Exists(...) && !Directory.Exists(resolvedTarget)`), skip the entry and add `(entry.FullPath, "broken symlink")` to `skipped` instead of calling `File.Copy` (which would throw).
**Where**: `src/McGui.Infrastructure.macOS/MacFileSystemService.cs`, `tests/McGui.Infrastructure.macOS.Tests/MacFileSystemServiceTests.cs` (extend)
**Depends on**: T7
**Reuses**: `CopySingleFile`/`skipped` from T7, `FileInfo.LinkTarget` (already used in `BuildEntry`)
**Requirement**: CPMV-09, CPMV-10, CPMV-12

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `FollowSymlinks: false` + symlink source → destination is a new symlink pointing at the same target (not a copy of the target's content)
- [ ] `FollowSymlinks: true` (default) + symlink source → destination is a real copy of the target's content (today's implicit behavior, unchanged)
- [ ] Broken symlink + `FollowSymlinks: true` → entry skipped, added to `OperationResult.Skipped` with "broken symlink" reason, no unhandled exception
- [ ] Gate check passes: `dotnet test tests/McGui.Infrastructure.macOS.Tests`
- [ ] Test count: existing facts + at least 3 new (link preserved, target followed, broken-link skipped), all passing

**Tests**: unit (real temp-dir I/O)
**Gate**: quick

**Commit**: `feat(infra): honor FollowSymlinks when copying symlink entries`

---

### T10: Apply options in the cross-volume Move fallback

**What**: `CopyDirectoryRecursively` (used by `ExecuteMove`'s fallback when `Directory.Move` fails across volumes) currently calls `File.Copy` directly, bypassing `CopySingleFile`. Change it to build a `FileEntry` per source file (reusing `BuildEntry`) and call `CopySingleFile` instead, so `PreserveAttributes`/`FollowSymlinks` apply on this path too. Thread `CopyMoveOptions`/`skipped` through `CopyDirectoryRecursively`'s signature.
**Where**: `src/McGui.Infrastructure.macOS/MacFileSystemService.cs`
**Depends on**: T9
**Reuses**: `CopySingleFile`, `BuildEntry` (both already exist by this point)
**Requirement**: CPMV-06, CPMV-10 (fallback-path parity, not new ACs)

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `CopyDirectoryRecursively` no longer calls `File.Copy` directly - it calls `CopySingleFile` for every file
- [ ] `dotnet build McGui.sln && dotnet test McGui.sln` passes (full suite, no regression - this path isn't independently testable in a same-volume CI environment, per the Test Coverage Matrix's documented gap)
- [ ] Test count: unchanged (no new test possible for this path per the matrix; existing tests for `CopySingleFile`'s behavior already cover the logic being reused, just not this specific call path)

**Tests**: none (documented gap - see Test Coverage Matrix; same-volume CI/dev cannot force this fallback to trigger)
**Gate**: full

**Commit**: `fix(infra): apply PreserveAttributes/FollowSymlinks in the cross-volume Move fallback`

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

Phase 1:  T1 → T2
Phase 1:  T1 → T3
Phase 2:  T4 → T5
Phase 3:  T5 → T6
Phase 3:  T5 → T7
Phase 4:  T6 → T8
Phase 4:  T7 → T9
Phase 5:  T9 → T10
```

Execution is strictly sequential - there is no intra-phase parallelism. Total: 10 tasks. Whether this runs inline or via batch sub-agents is decided at Execute time (count tasks then, per `sub-agents.md`) - not decided here, since Execute is deferred to a future session.

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: Add Update enum value | 1 file, 1 value | ✅ Granular |
| T2: Update button in conflict dialog | 1 ViewModel + 1 view (cohesive pair) | ✅ Granular |
| T3: Handle Update in conflict switch | 1 file, 1 concern (2 switch blocks, same logic) | ✅ Granular |
| T4: CopyMoveOptions model | 1 new file | ✅ Granular |
| T5: Thread options through interface | 1 interface + its 2 implementations + call sites (single cohesive plumbing change) | ⚠️ OK - mechanical signature propagation, no branching logic added; splitting further would leave the solution non-compiling between tasks |
| T6: Preserve-attributes checkbox | 1 ViewModel + 1 view (cohesive pair) | ✅ Granular |
| T7: Preserve attributes in copy | 1 file, 1 concern | ✅ Granular |
| T8: Follow-symlinks checkbox | 1 ViewModel + 1 view (cohesive pair) | ✅ Granular |
| T9: Symlink gate | 1 file, 1 concern, extends T7's method | ✅ Granular |
| T10: Cross-volume fallback parity | 1 file, 1 concern | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | None | ✅ Match |
| T2 | T1 | T1 → T2 | ✅ Match |
| T3 | T1 | T1 → T3 | ✅ Match |
| T4 | None | None | ✅ Match |
| T5 | T4 | T4 → T5 | ✅ Match |
| T6 | T5 | T5 → T6 | ✅ Match |
| T7 | T5 | T5 → T7 | ✅ Match |
| T8 | T6 | T6 → T8 | ✅ Match |
| T9 | T7 | T7 → T9 | ✅ Match |
| T10 | T9 | T9 → T10 | ✅ Match |

T2 and T3 execute in that order within Phase 1 (T2 then T3) even though neither's `Depends on` names the other - both depend only on T1. Same pattern for T6/T7 in Phase 3 (both depend only on T5).

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: Update enum value | Core model/enum | unit | none | ⚠️ See note |
| T2: Update button | App ViewModel/XAML | unit | unit | ✅ OK |
| T3: Update conflict handling | Infrastructure file ops | unit | unit | ✅ OK |
| T4: CopyMoveOptions model | Core model/enum | unit | unit | ✅ OK |
| T5: Thread options through interface | mechanical plumbing, no new branching logic | - | none | ✅ OK (no behavior introduced - matrix's "unit" row applies to logic, not signature changes) |
| T6: Preserve-attributes checkbox | App ViewModel/XAML | unit | unit | ✅ OK |
| T7: Preserve attributes in copy | Infrastructure file ops | unit | unit | ✅ OK |
| T8: Follow-symlinks checkbox | App ViewModel/XAML | unit | unit | ✅ OK |
| T9: Symlink gate | Infrastructure file ops | unit | unit | ✅ OK |
| T10: Cross-volume fallback parity | documented gap row | none | none | ✅ OK |

**Note on T1**: a bare enum value with zero branching logic has nothing to assert beyond "the value exists," which the compiler already guarantees (T2/T3 reference `FileConflictResolution.Update` and would fail to compile otherwise). The matrix's "unit, 1:1 to spec ACs" applies to the enum's *usage* (T2's button, T3's comparison logic), both of which do carry dedicated tests. This mirrors the `macos-native-chrome` feature's precedent for zero-logic scaffolding tasks.

---

## Tips

- **Re-read spec.md/design.md before Execute** - this file was authored ahead of implementation; do not implement from memory of this session
- **Phase 2 unblocks Phase 3+4, not Phase 1** - "Update" (P1) only touches the enum + conflict dialog + switch statement, it does not need `CopyMoveOptions` at all
- **T7 creates `CopySingleFile`, T9 extends it, T10 reuses it** - do not let a re-planning pass split these three into unrelated methods; the whole point of centralizing in T7 is that T9/T10 build on the same method
- **One commit per task** - Conventional Commits, validated via `check_commit.py`
- **Full suite before T5, T10** - these are the only tasks touching more than one project

---

## Task Verification Standards

Every task MUST follow the `Done when` + `Tests` + `Gate` fields defined above. Each `Done when` entry must be specific, testable (binary pass/fail), and reference the gate check command from the **Gate Check Commands** section. Include the expected test count to prevent silent deletions.
