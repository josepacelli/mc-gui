# Dual-Pane Core — Independent Verification Report

**Verdict: PASS** (P1 acceptance criteria DPC-01..DPC-31 all spec-anchored and matched; gate green; survived mutants are test-strength gaps, not demonstrated behavior defects — see Ranked Gaps).

- Verifier: independent (author != verifier). No production/test code was modified. Real working tree untouched except this file.
- Commit range verified: `e0e28e5..07628e5` (31 commits incl. both endpoints; feature Execute + post-Execute `/simplify` pass `11a4a47..07628e5`).
- HEAD at verification: `07628e5`.
- Baseline `git status --porcelain`: ` M .specs/STATE.md` — pre-existing, uncommitted state-file note describing the (now-finished) simplify planning. Left untouched. Matches exactly after sensor run.
- Source of truth: `.specs/features/dual-pane-core/spec.md`. Success Criteria #2 gates only P1 `DPC-01..DPC-31`; P2 (DPC-32..36) / P3 are not part of this feature's gate and are reported informatively.

---

## Gate exit results

| Project | Result |
| --- | --- |
| McGui.Core.Tests | 13 passed / 0 failed |
| McGui.Infrastructure.macOS.Tests | 30 passed / 0 failed |
| McGui.App.Tests | 63 passed / 0 failed |
| **Total** | **106 passed / 0 failed** |

`dotnet test McGui.sln` run on the real tree at `07628e5` — clean exit, matches expected 13 + 30 + 63 = 106.

---

## Spec-anchored coverage matrix (P1, DPC-01..DPC-31)

Each row: spec outcome -> test `file:line` -> assertion (value/state asserted, not just "a call occurred") -> verdict. Paths relative to repo root.

| DPC | Spec outcome (condensed) | Evidence: test file:line | Assertion | Verdict |
| --- | --- | --- | --- | --- |
| DPC-01 | Two side-by-side panels, each listing a directory at start | `tests/McGui.App.Tests/ViewModels/MainWindowViewModelTests.cs:18` + `.../PanelViewModelTests.cs:16`; visual via `src/McGui.App/Views/MainWindow.axaml` + manual run (T15/T21) | ctor builds Left/Right `PanelViewModel`; panel ctor lists persisted dir contents (`Assert.Single(vm.Entries)`); View-layer "side-by-side" is manual-only per Test Coverage Matrix | PASS |
| DPC-02 | Tab moves focus to other panel + visual highlight | `MainWindowViewModelTests.cs:31` (toggle L→R) and `:44` (toggle twice → L) | `Assert.Same(vm.RightPanel, vm.ActivePanel)`, `IsActive` flags flipped on both panels. Visual border = `Classes.active` binding in `PanelView.axaml` (build-gated), manual per matrix | PASS |
| DPC-03 | Up/Down move cursor, stop (no wrap) at first/last | `PanelViewModelTests.cs:85` (Down x3 at last), `:100` (Up at first) | `Assert.Equal(1, vm.CursorIndex)` / `Assert.Equal(0, ...)` | PASS |
| DPC-04 | Enter on directory -> navigate + refresh listing | `PanelViewModelTests.cs:41` (`NavigateToAsync`), `:71` (`ActivateCursorEntryAsync`) | `CurrentDirectory == "/root/sub"`, `Entries` == single `nested.txt` | PASS |
| DPC-05 | Backspace or ".." entry -> parent | `PanelViewModelTests.cs:57` (`NavigateToParentAsync`); Back→NavigateToParent in `KeyGestureMap.cs:27` + `KeyGestureMapTests.cs:31` | `CurrentDirectory == "/root"` | PASS (spec-precision: only the Backspace alternative is implemented/tested; ".."-row activation is P2 DPC-36 — see gaps) |
| DPC-06 | Listing >500ms -> loading indicator | `PanelViewModelTests.cs:113` (slow, shows), `:133` (fast, never) | `IsLoading` true mid-flight then false; never true under threshold. 500ms threshold injectable (spec-precision gap) | PASS |
| DPC-07 | Close persists both panel dirs for restore | `tests/McGui.Infrastructure.macOS.Tests/MacPathHistoryStoreTests.cs:15` (Save→Load round-trip); `PanelViewModelTests.cs:292` (saves own side only) | restored paths equal saved; per-side update. Close-wiring glue = `src/McGui.App/MainWindow.axaml.cs:22-31` (`Window.Closing` → `PersistCurrentDirectory` on both panels; T21 fix) | PASS |
| DPC-08 | Persisted path missing at launch -> home fallback (per panel) | `MacPathHistoryStoreTests.cs:56` (per-panel fallback), `:43`/`:71` (no file / corrupt JSON → home both); `PanelViewModelTests.cs:29` | valid panel kept, invalid one → home; empty dir rejected | PASS |
| DPC-09 | Insert/Space toggles marked + cursor advances | `tests/McGui.Core.Tests/Services/SelectionServiceTests.cs:22,33,44`; `PanelViewModelTests.cs:156` | mark/unmark sets `MarkedPaths`; `CursorIndex` advanced/clamped | PASS |
| DPC-10 | "+" glob marks all matches | `SelectionServiceTests.cs:54` (matches) and `:66` (no match → none) | `MarkedPaths` contains exactly `*.txt` matches | PASS (case-sensitivity undefined in spec — flagged in T6) |
| DPC-11 | "-" glob unmarks all matches | `SelectionServiceTests.cs:76` | non-matching stay marked, matching removed | PASS |
| DPC-12 | "*" inverts every entry | `SelectionServiceTests.cs:89`; `PanelViewModelTests.cs:189` | marked→unmarked, unmarked→marked for every entry | PASS |
| DPC-13 | Status line: live marked count + total bytes | `SelectionServiceTests.cs:102`; `PanelViewModelTests.cs:204` | count == 2, `MarkedSizeBytes == 350`; `PropertyChanged` raised for `MarkedCount`/`MarkedSizeBytes` | PASS |
| DPC-14 | F5 opens copy dialog prefilled with opposite-panel dir (editable) | `MainWindowViewModelTests.cs:58` (prefill), `:116` (zero sources → no dialog) | `DestinationDirectory == "/right"`, single source `/left/a.txt`; dest bound to editable `TextBox` (`CopyMoveDialog.axaml:13`) | PASS |
| DPC-15 | Confirm copies recursively + progress (% / file / Cancel) | `MacFileSystemServiceTests.cs:92` (recursive, content byte-equal), `:114` (per-entry progress); `CopyMoveDialogViewModelTests.cs:54`; `ProgressDialogViewModelTests.cs:9,21,31` | dest tree exists with `nested-content`; final report `FilesDone==FilesTotal==2`; percent 25 from bytes / 50 from files | PASS |
| DPC-16 | Existing dest → Overwrite/Skip/Rename/Abort + apply-to-all before write | `MacFileSystemServiceTests.cs:160` (Theory Overwrite/Skip/Rename), `:192` (Abort); `CopyMoveDialogViewModelTests.cs:120,136`; `ConflictDialogViewModelTests.cs:9..62` | Overwrite→dest=new content; Skip→dest keeps `old-content`, nothing else written; Rename→`dup 2.txt` byte-identical (`new-content`); Abort→`Succeeded==false` + single skipped entry + conflicted dest untouched; apply-to-all→prompt fires once, both files overwritten; 4 dialog commands resolve to 4 resolutions + `ApplyToAll` flag | PASS |
| DPC-17 | Cancel stops after current file, prior files kept (no rollback) | `MacFileSystemServiceTests.cs:133`; `CopyMoveDialogViewModelTests.cs:155` | `a.txt` exists, `b.txt` absent after cancel at `FilesDone==1` | PASS |
| DPC-18 | Dest == source or its subdir → reject w/ circular error | `CopyMovePlannerTests.cs:51` (copy into own subdir); `CopyMoveDialogViewModelTests.cs:208` (message) and `:193` (missing dest NOT created when circular) | `CopyMovePlanValidationException` message contains "circular"; `ErrorMessage` set, `IsCompleted==false`, nothing written | PASS |
| DPC-19 | Insufficient space → abort BEFORE any copy, show required + available bytes | `MacFileSystemServiceTests.cs:209`; `CopyMoveDialogViewModelTests.cs:236` | exception `AvailableBytes==1`; dest file absent; `ErrorMessage == "Insufficient disk space: required 7 bytes, available 1 bytes."`, `IsCompleted==false`, nothing written. `EnsureSufficientSpace` is first statement of `ExecuteCopy` (`MacFileSystemService.cs:66`) | PASS |
| DPC-20 | F6 move applies same conflict/free-space rules as copy | `MacFileSystemServiceTests.cs:251` (Overwrite), `:268` (plain move), `:299` (permission skip+continue); `ExecuteMove` shares `EnsureSufficientSpace` (`MacFileSystemService.cs:147`) | move replaces dest content and removes source; dest exists after move; permission errors skipped+reported, sources kept | PASS (gap: Move-mode Skip/Rename/Abort and insufficient-space not individually asserted — see gaps) |
| DPC-21 | Single entry, name-only edit → in-place rename | `MacFileSystemServiceTests.cs:284`; `CopyMoveDialogViewModelTests.cs:89`; prefill rule `MainWindowViewModelTests.cs:75` | `old-name.txt` gone, `new-name.txt` exists with same payload; `CanRename` true only for Move+1 source | PASS |
| DPC-22 | Move dir into itself / own subdir → rejected w/ error | `CopyMovePlannerTests.cs:64` | exception message contains "circular"; shared `IsSameOrSubdirectory` guard (`CopyMovePlanner.cs:69`) | PASS (copy-into-self / move-into-subdir diagonals not individually asserted — see gaps) |
| DPC-23 | Moving other panel's current dir → blocked w/ explanation | `CopyMovePlannerTests.cs:77`; `CopyMoveDialogViewModelTests.cs:222` | `otherPanelCurrentDir` guard throws "other panel"; VM `ErrorMessage` contains "other panel", not completed | PASS |
| DPC-24 | F7 prompts + creates folder in active panel dir | `MacFileSystemServiceTests.cs:63`; `MkdirDialogViewModelTests.cs:25`; `MainWindowViewModelTests.cs:179` | `Directory.Exists(parent/new-folder)`; dialog `ParentDirectory == ActivePanel.CurrentDirectory` | PASS |
| DPC-25 | Duplicate name → inline error, dialog stays open | `MacFileSystemServiceTests.cs:73`; `MkdirDialogViewModelTests.cs:37` | `IOException`; `HasError` true, `IsCompleted==false` (stays open), message set | PASS |
| DPC-26 | Invalid char → inline error identifying the character | `MacFileSystemServiceTests.cs:82`; `MkdirDialogViewModelTests.cs:50` | `ArgumentException`; `ErrorMessage` contains `/`; dialog open | PASS |
| DPC-27 | F8 confirmation lists count + total size | `DeleteConfirmDialogViewModelTests.cs:43`; `MainWindowViewModelTests.cs:148` | `Count==2`, `TotalSizeBytes==15` (5+10); sources forwarded | PASS |
| DPC-28 | Confirm → move to OS trash, not permanent | `MacTrashServiceTests.cs:16` (home `.Trash`), `:50` (dir tree), `:33` (collision rename `doc 2.txt`, Finder convention); `DeleteConfirmDialogViewModelTests.cs:56` | source removed, `.Trash/doc.txt` byte-identical; collision keeps `already-in-trash` at `doc.txt` and stores `new-delete` at `doc 2.txt`; VM `Result.Succeeded` + `IsCompleted` | PASS |
| DPC-29 | No trash available → permanent delete | `MacTrashServiceTests.cs:81` | `trashRootForPath => null` resolver → file deleted, nothing in `.Trash` | PASS |
| DPC-30 | Shift+confirm → permanent, bypassing trash, irreversible wording | `MacTrashServiceTests.cs:66`; `DeleteConfirmDialogViewModelTests.cs:75`; wording `DeleteConfirmDialog.axaml:15` | no `.Trash` created; trash dir empty, `Permanent==true`; axaml text "...cannot be undone"; distinct `ConfirmPermanentCommand` only permanent call site (grep `permanent: true`) | PASS |
| DPC-31 | Permission failure → skip entry, continue batch, report path+reason at finish | `MacTrashServiceTests.cs:119` (batch: one blocked + one ok), `:94` (unwritable trash root) | `Succeeded==false`, `SkippedEntries[0].Path==blockedFile`, ok entry still trashed; blocked file untouched; skip reason is `ex.Message` in `OperationResult.SkippedEntries` | PASS (gap: summary never surfaced in UI — see gaps) |

### Edge Cases & Success Criteria

| Item | Evidence | Verdict |
| --- | --- | --- |
| Zero entries (no marks, no cursor) → do nothing, no dialog | `MainWindowViewModelTests.cs:116` (Copy), `:132` (Move), `:163` (Delete) | PASS |
| Panel dir becomes inaccessible → inline error + "go to home" action | `PanelViewModelTests.cs:226` (navigate), `:243` (refresh), `:259` (GoToHome clears error), `:277` (accessible reload OK) | PASS |
| Missing dest dir in Copy/Move dialog → offer to create on confirm | `CopyMoveDialogViewModelTests.cs:177` (created), `:193` (not created when circular) | PASS |
| Symlink: Move/Delete act on link, Copy follows target | **No automated test.** Only symlink *detection* covered (`MacFileSystemServiceTests.cs:46`). Neither copy-follows-target nor move/delete-on-link semantics exercised on a real symlink | **GAP** |
| SC: full keyboard cycle on macOS | Manual (T21) + integration suite; visual click-through of F5/F6/F8 dialogs pending manual session (documented T21 limitation) | PASS (matrix: Views manual) |
| SC: all 31 P1 ACs (DPC-01..31) have passing automated test | This matrix | PASS |
| SC: no delete bypasses trash without explicit Shift | `ConfirmPermanentCommand` sole `permanent: true` caller (`DeleteConfirmDialogViewModel.cs:39`); tests `:66`/`:75` | PASS |
| SC: panel dirs restored after restart | `MacPathHistoryStoreTests.cs:15` + `MainWindow.axaml.cs:22-31` | PASS |
| SC: no macOS dependency outside `McGui.Infrastructure.macOS` | Only infra project P/Invokes `libc` (`MacTrashService.cs:95`) / uses `VolumeLocator`; App references infra only for DI composition + `InsufficientDiskSpaceException` type | PASS |

Informational (out of MVP gate): DPC-32 Ctrl+R refresh is implemented (`RefreshCommand`, `PanelViewModel.cs:167`) and tested (`PanelViewModelTests.cs:243,277`). DPC-33..36 (type-to-filter, column sort, Ctrl+H hidden toggle binding target, ".." first) are not implemented — P2 scope, matches traceability table ("Pending") and Success Criteria #2 (P1 only). Not counted in verdict.

---

## Discrimination sensor (isolated worktree only)

Temp git worktree at `07628e5`, 8 behavior-level faults injected one at a time in the worktree (never the real tree), targeted `dotnet test` per mutant, revert between runs. Real tree confirmed byte-identical to baseline after removal.

| # | Mutant (regression seeded) | Target | Result |
| --- | --- | --- | --- |
| 1 | `NamingCollisionResolver`: collision counter starts at 3 (Finder rename becomes `doc 3.txt`) | Infra | **KILLED** — `MacTrashServiceTests.Delete_NameCollisionInTrash_RenamesUsingFinderConvention` + `MacFileSystemServiceTests.CopyAsync_NameConflict_AppliesRequestedResolution(Rename)` fail |
| 2 | `ExecuteMove`: subtree-size precompute skipped (`entrySize = 0` for every moved entry) | Infra + App | **SURVIVED** — 30 + 63 pass. No test asserts move byte totals / subtree accounting |
| 3 | `NamingCollisionResolver.ResolveCollision` returns original path unchanged (collision rename disabled) | Infra | **KILLED** — both collision tests above fail |
| 4 | `PanelViewModel.TryLoadDirectoryAsync`: error-state assignment removed on failure | App | **KILLED** — `NavigateToAsync_InaccessibleDirectory_ShowsInlineErrorStateWithoutNavigating` + `RefreshAsync_CurrentDirectoryNoLongerExists_ShowsInlineErrorState` fail |
| 5 | `CopyMoveDialogViewModel.ConfirmAsync`: `InsufficientDiskSpaceException` catch removed | App | **KILLED** — `ConfirmAsync_InsufficientDiskSpace_SetsErrorMessageWithByteCounts` fails |
| 6a | `DeleteConfirmDialogViewModel`: `IsCompleted` never set after delete | App | **KILLED** — `Confirm_MovesEntryToTrashAndExposesResult` + `ConfirmPermanent_DeletesEntryWithoutUsingTrash` fail |
| 6b | `DeleteConfirmDialogViewModel`: delete runs synchronously again (`Task.Run` removed, fix-6 regression) | App | **SURVIVED** — 63 pass. Thread-offload is not discriminated by any test |
| 7 | `MacTrashService.DefaultTrashRootForPath`: always returns home `.Trash` (cross-volume `.Trashes/<uid>` branch dead, fix-2 regression) | Infra | **SURVIVED** — 30 pass. No test exercises a volume different from home (all temp dirs share the root volume; cross-volume covered only via injected resolver) |

Sensor summary: **8 injected / 5 killed / 3 survived.** Survived mutants are the verification findings (test-strength gaps), not demonstrated wrong behavior — each surviving fault changes behavior only in a context no current test observes.

---

## Payload / conjunction rule spot-check

Payloads asserted on value/state, not merely "call occurred" (verified PASS except noted):
- `OperationProgress`: `BytesDone`/`FilesDone` byte-count semantics asserted for **copy** (`MacFileSystemServiceTests.cs:114,129` reports count and last `FilesDone==FilesTotal`); percent derivation asserted in `ProgressDialogViewModelTests.cs:21,31`. **Move** byte totals (`BytesDone`, precomputed subtree sizes) are **not** asserted anywhere — conjunction violation (see gaps, mutant 2).
- `OperationResult.SkippedEntries`: path asserted by equality (`MacTrashServiceTests.cs:109,141`; `MacFileSystemServiceTests.cs:241-242`), reason asserted implicitly (`ex.Message` stored). Copy/move/delete failure summaries are stored in `Result`/`LastResult` but **never rendered in any View** — data plane verified, presentation plane absent (see gaps).
- `PanelState.MarkedPaths`: asserted on set membership + derived `MarkedCount`/`MarkedSizeBytes` values (`PanelViewModelTests.cs:204-223`).
- `IsCompleted`/`HasError`/`IsDirectoryInaccessible`: asserted as state transitions including negative cases (dialog stays open on inline errors: `MkdirDialogViewModelTests.cs:44`; error cleared on home navigation: `PanelViewModelTests.cs:271`).

---

## Ranked gaps (do not block PASS; none is an unmatched P1 AC)

1. **Symlink operation semantics untested** (Edge Case bullet). No test proves Copy follows the link target or Move/Delete act on the link itself. .NET symlink Move/Delete behavior is subtle (rename-vs-follow) and currently unlocked. *Fix:* integration tests on real symlinks (file + dir targets) for copy/move/delete.
2. **Move progress byte totals unlocked** (mutant 2 survived). `BuildSubtreeSizes` (fix 7) has zero discriminating coverage; a fault zeroing moved-directory bytes passes 93 tests. *Fix:* assert final/ongoing `BytesDone` for a move of a directory containing files.
3. **Delete off-UI-thread not discriminated** (mutant 6b survived). A synchronous (UI-blocking) delete regression would pass the suite. *Fix:* blocking fake `ITrashService` + assert `IsCompleted`/`Result` are not set until the delete returns.
4. **Cross-volume trash root branch unverified** (mutant 7 survived; environment limitation acknowledged in T9). `.Trashes/<uid>` resolution (fix 2) never executes in a test; only same-volume default + injected resolver paths run. *Fix:* needs a second physical volume or an injected `VolumeLocator` seam.
5. **No user-visible report of skipped/failed entries** after Copy/Move/Delete (DPC-31 "report ... once the operation finishes"; design "resumo dos itens pulados"). `OperationResult.SkippedEntries` is populated and asserted at the service/VM boundary, but no View surfaces it — dialogs close on `IsCompleted` and panels refresh silently. *Fix:* completion summary presentation + test.
6. **Move-mode conflict matrix partially covered** (DPC-20): Move+Skip / Move+Rename / Move+Abort and Move-insufficient-space are not individually asserted (only Overwrite + plain move + permission path). Shared code inspected; Add theory coverage for Move resolutions.
7. **Spec-precision gaps (informational, no failing assertion):** (a) DPC-05 lists ".."-entry activation but ".." rows are a P2 DPC-36 requirement — MVP implements only the Backspace alternative; (b) DPC-06 500ms threshold injectable; (c) DPC-08 fallback is per-panel not all-or-nothing; (d) DPC-10/11 glob case-sensitivity undefined; (e) F6 single-entry dialog prefills the *source's own directory* (spec only defines F5 prefill); (f) DPC-18/22 diagonal cases (copy-into-self, move-into-own-subdir) not individually asserted though guarded by the same `IsSameOrSubdirectory` method; (g) "offer to create missing destination" implemented as silent auto-create with no second prompt and only last-level creation.

---

## Environment / process notes

- `.specs/STATE.md` was already modified (uncommitted) before verification began — stale planning note about the simplify pass; contents superseded by the actual simplify commits present at HEAD. Recorded, not touched.
- Sensor ran against infra + App projects only where the expected killer lives (fast); mutant 2 additionally checked against both suites (93 tests) before recording survival.
- Commit range `e0e28e5..07628e5`: 31 commits. Nothing committed after `07628e5` during or after verification (`worktree list` shows only the main repo).

---

## Follow-up (post-report, authored independently of the Verifier)

The two surviving mutants that were cheaply addressable with regression tests became fix tasks. Both are now closed; the two remaining survivors (cross-volume trash root; sync-delete UI-blocking variant) are environmental/architectural and recorded as accepted gaps below.

| Gap | Resolution | Evidence |
| --- | --- | --- |
| 2. Move progress byte totals unlocked (mutant 2) | Added `MoveAsync_DirectoryTree_ReportsSubtreeBytesInProgress` (commit `1e92d9d`) — moves a directory tree via a 3-entry plan, asserts final report `FilesDone==1`, `BytesDone==expectedBytes`, `BytesTotal==expectedBytes`. Re-injected the mutant (`entrySize = 0`) in a throwaway worktree at `1e92d9d` → infra suite fails 1 (test now kills it); worktree discarded, real tree byte-identical. | `tests/McGui.Infrastructure.macOS.Tests/MacFileSystemServiceTests.cs:322` |
| 3. Delete off-UI-thread not discriminated (mutant 6b) | Added `Confirm_DoesNotCompleteUntilBackgroundDeleteReturns` (commit `3d92359`) using a blocking `BlockingTrashService` (gate + `ManualResetEventSlim`): asserts `IsCompleted` is false right after `ConfirmCommand.ExecuteAsync(null)` starts and true only after the gate is released. Re-injected the sync-delete mutant in a throwaway worktree → hangs (never yields), then re-injected an equivalent premature-`IsCompleted` mutant → DeleteConfirmDialogViewModelTests fails 1 cleanly; both scratch states discarded, real tree byte-identical. | `tests/McGui.App.Tests/ViewModels/DeleteConfirmDialogViewModelTests.cs:104` |

Sensor status after follow-up: **8 injected / 7 killed / 1 survived** (survivor = cross-volume `.Trashes/<uid>` branch, environment-limited per T9; needs a second physical volume or a `VolumeLocator` seam). Gate after follow-up: **108 passed / 0 failed** (13 Core + 31 Infra + 64 App). Feature HEAD now `3d92359`. Verdict remains **PASS** — remaining ranked gaps (1 symlink-semantics tests, 4 cross-volume trash, 5 UI summary of skipped entries, 6 Move-mode conflict matrix theory, 7 spec-precision informational) do not block; none is an unmatched P1 AC.

