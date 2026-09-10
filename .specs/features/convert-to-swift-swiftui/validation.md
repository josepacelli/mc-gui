# Convert to Swift and SwiftUI Validation

## Validation: convert-to-swift-swiftui - PASS ✅

**Date**: 2026-09-10
**Spec**: `.specs/features/convert-to-swift-swiftui/spec.md`
**Diff range (iteration 2)**: `f64f3ec..HEAD` (`973d0a9`), re-verifying on top of the iteration-1 report below. One commit addressed the iteration-1 gap: `2223763` "fix(ui): wire Insert's advance-cursor half (KN-06)", scoped entirely to `Sources/MCGuiUI/Views/PanelView.swift`. Two more commits landed on the branch concurrently with this re-verification, both confirmed unrelated to KN-06/KN-05 or any other AC in scope: `0ab4d15` (packaging installer script fix, `.NET` → `swift build -c release`) and `973d0a9` (cosmetic window/app title rename "MCGui" → "Midnight Commander", `WindowManager.swift`/`Info.plist` only). Neither touches `PanelView.swift`, `PanelCommands.swift`, or `SelectionService.swift`.
**Verifier**: independent sub-agent (author ≠ verifier) - iteration 2 of the bounded fix→reverify loop. Re-derived KN-06 from scratch with fresh evidence rather than trusting the commit message's own summary of what it did; carried forward the iteration-1 report's other already-confirmed ACs without re-deriving them (per this iteration's task scope), but did re-run the full gate and spot-checked KN-05/native-List-nav for regression as instructed.

**Iteration 1 verdict (preserved for history)**: FAIL ❌ - single gap, KN-06's "move down" half unwired. Full iteration-1 evidence tables below are unchanged except where marked "iteration 2 update".

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| Fix 1 (FO-05..09 conflict dialog wiring) | ✅ Done | Verified with file:line evidence below |
| Fix 2 (FS-04/05/KN-11 Enter/Backspace/".." nav) | ✅ Done | Verified |
| Fix 3 (FO-14/16 progress + cancel) | ✅ Done | Verified |
| Fix 4 (KN-04/05/06/12, SF-04) | ✅ Done | KN-04/05/12/SF-04 done (iteration 1); **KN-06's "move down" half wired in iteration 2** (`2223763`) - see updated evidence below |
| Fix 5 (FV-02/03 viewer highlighting/zoom) | ⚠️ Partial (accepted) | Line numbers + image zoom/pan done; syntax highlighting honestly deferred, same documented pattern as ED-02 |
| Fix 6 (Edge Cases 4/6/7) | ✅ Done (4 deliberately, honestly deferred) | 6/7 fixed with real throws; 4 deferred with a genuine `SPEC_DEVIATION` |

No task is blocked. One fix (Fix 4) is only partially complete against its own stated scope (spec.md's KN-06 text, not just this fix cycle's summary of itself).

---

## Spec-Anchored Acceptance Criteria

Only the IDs in scope for this re-verification are re-derived below (the 14 previously-GAP IDs, KN-05, and the 3 Edge Cases), plus a regression spot-check of previously-PASSING ACs in the shared files this fix cycle touched (`PanelView.swift`, `FileSystemServiceImpl.swift`, `FileSystemService.swift`). All other IDs (SWIFT-*, most FS-*/FO-*/FV-*/ED-*/TH-*/MB-*, P2/P3) are unchanged by this diff and were not re-derived from scratch; see the prior report's tables for those, which remain the last independent evidence for them.

### P1: File Operations - conflict dialog (FO-05..09)

| Criterion | Spec-defined outcome | file:line + evidence | Result |
| --- | --- | --- | --- |
| FO-05: destination-exists shows conflict dialog | `ConflictDialog` presented, real flow | `PanelView.swift:383-396` (`performCopyMove` computes `CopyMovePlanner.conflicts` against a live `listDirectory` of the destination, then calls `resolveConflict` per conflict); `PanelView.swift:460-467` (`resolveConflict` sets `conflictDialogViewModel`, which `body`'s `.sheet(isPresented: presented($conflictDialogViewModel))` at `PanelView.swift:138-142` actually presents) | ✅ PASS |
| FO-06: Overwrite replaces destination | destination replaced on user choice | `PanelView.swift:536-538` (`.overwrite: continue` - source left in the batch); `FileSystemServiceImpl.swift:258-274` (`resolveExistingDestination` removes the existing file unconditionally outside `updateOnly`); `FileSystemServiceImplCopyMoveTests.swift:131-147` "copy overwrites an existing destination file by default" | ✅ PASS |
| FO-07: Skip continues with next file | conflicting source dropped, rest proceed | `PanelView.swift:539-540` (`.skip: remainingSources.removeAll { $0.id == entry.id }`); `PanelViewFileOperationsTests.swift:231-243` "skip removes the conflicting source from the batch" - asserts `.proceed(sources: [b], renames: [:])` exactly | ✅ PASS |
| FO-08: Rename auto-suffixes (`file (1).txt`) | numeric-suffix rename on user choice | `PanelView.swift:541-545` (`.rename` calls `CopyMovePlanner.resolvedName`, threading `renames` into the `CopyMovePlan`); `PanelViewFileOperationsTests.swift:245-256` asserts `renames: [a.id: "a (1).txt"]` exactly; `FileSystemServiceImplCopyMoveTests.swift:190-211` "copy writes to the renamed destination name when plan.renames has an entry" confirms the plan's `renames` actually reaches disk | ✅ PASS |
| FO-09: Cancel aborts entire operation | operation not performed | `PanelView.swift:395` (`if resolution == .cancel { break }`) + `PanelView.swift:546-547` (`.cancel: return .cancelled`) + `PanelView.swift:403-404` (`case .cancelled: return` - no `CopyMovePlan` built, `fileSystemService.copy`/`.move` never called); `PanelViewFileOperationsTests.swift:275-287` "cancel aborts the entire batch, not just the file being resolved" | ✅ PASS |

**Reachability confirmed**: `grep -rn "ConflictDialog(\|CopyMovePlanner\." Sources/` now shows real call sites in `PanelView.swift`, not just the dialogs' own files - the dead-code pattern the prior report found is gone.

### P1: File System Service - directory navigation (FS-04, FS-05) / Keyboard (KN-11)

| Criterion | Spec-defined outcome | file:line + evidence | Result |
| --- | --- | --- | --- |
| FS-04: Enter on directory navigates into it | directory becomes current path | `PanelView.swift:643-645` (`.onKeyPress(.return) { onReturn() ... }` on the real `List`, `PanelView.swift:174-201` `entryList`) → `activateSelected` → `activate(entry)` (`PanelView.swift:323-330`) → `Self.activationResult(for:)` (`PanelView.swift:479-481`, `.directory` → `.navigate`) → `Task { await viewModel.load(target) }`; `PanelViewFileOperationsTests.swift:193-198` "activationResult for a directory navigates to its path" | ✅ PASS |
| FS-05: Backspace navigates to parent | parent becomes current path | `PanelView.swift:646-649` (`.onKeyPress(.delete) { onBackspace() ... }` - `KeyEquivalent.delete` is AppKit/SwiftUI's mapping for the physical Backspace key, `.deleteForward` is the separate forward-delete) → `navigateToParent()` (`PanelView.swift:334-336`, `viewModel.load(currentPath.deletingLastPathComponent())`) | ✅ PASS (logic path confirmed; no XCUITest exists to press the physical key end-to-end, consistent with the project's pre-accepted no-Xcode-project limitation) |
| ".." synthetic entry (FS-04/05/KN-11 support) | ".." row at top, absent at root | `PanelView.swift:95-100` (`displayEntries` prepends `Self.parentEntry(for:)`); `PanelView.swift:491-507` (`nil` when `parent.path == currentPath.path`); `PanelViewFileOperationsTests.swift:172-189` both cases exactly asserted; `PanelViewFileOperationsTests.swift:200-205` activating the ".." entry itself navigates to its (parent) path | ✅ PASS |
| KN-11: Enter enters directory / opens file | as FS-04, plus file-open | `PanelView.swift:479-481` (`activationResult`: non-directory → `.view(entry)`); `PanelViewFileOperationsTests.swift:207-212` "activationResult for a file opens it in the viewer" | ✅ PASS |

### P1: File Operations - progress + cancel (FO-14, FO-16)

| Criterion | Spec-defined outcome | file:line + evidence | Result |
| --- | --- | --- | --- |
| FO-14: progress dialog during operation (file, bytes, speed, ETA) | `ProgressDialog` shown mid-copy with real numbers | `PanelView.swift:428-456` (`runWithProgress` builds an `AsyncStream<OperationProgress>`, sets `self.progressViewModel`, presented by `body`'s `.sheet(isPresented: presented($progressViewModel))` at `PanelView.swift:143-147`); `FileSystemServiceImpl.swift:164,178,184` (`copy(_:onProgress:)` calls `onProgress(progress.recordProcessed(source))` once per source); `FileSystemServiceImplCopyMoveTests.swift:220-247` "copy(_:onProgress:) reports one snapshot per source, in order, with the running byte total" - asserts exact `bytesTransferred` sequence `[4, 12]`; `OperationProgressTrackerTests.swift:60-77` "speed reflects bytesTransferred over elapsed time, eta reflects remaining bytes at that speed" - asserts exact `speed == 10`, `eta == 10` | ✅ PASS |
| FO-16: cancel an in-progress operation | operation stops | `PanelView.swift:440` (`ProgressDialogViewModel(onCancel: { task.cancel() })`); `FileSystemServiceImpl.swift:173,217` (`try Task.checkCancellation()` between sources in both `copy`/`move`); `FileSystemServiceImplCopyMoveTests.swift:248-279` "cancelling the calling Task stops copy(_:onProgress:) before processing every source" - asserts neither destination file exists after cancellation; also reachable via Escape (`PanelView.swift:357-361`, `progressViewModel.cancel()`) | ✅ PASS |

**Reachability confirmed**: `FileSystemService.copy`/`.move(_:onProgress:)` (`Sources/MCGuiCore/Protocols/FileSystemService.swift:38-40`) is a real protocol requirement now, with a non-breaking default-implementation fallback (`FileSystemService.swift:47-58`) for conformers (e.g. mocks) that don't override it - `MockFileSystemService` unaffected, no test breakage from the signature addition.

### P1: Keyboard Navigation & Shortcuts (KN-04, KN-05, KN-06, KN-12) / SF-04

| Criterion | Spec-defined outcome | file:line + evidence | Result |
| --- | --- | --- | --- |
| KN-04: Cmd+Arrow jump to first/last | selection jumps to first/last row | `PanelView.swift:665-673` (`.onKeyPress(keys: [.leftArrow, .rightArrow])`, `press.modifiers.contains(.command)`) → `jumpToEdge` (`PanelView.swift:340-343`) → `PanelCommands.jump(toFirst:entries:)` (real call, not dead code); `PanelCommandsTests.swift:70-80` asserts exact first/last ids | ✅ PASS - **with a spec-precision note**: spec.md's literal text says "Cmd+Arrow" without specifying which axis; this binds Cmd+Left/Right rather than Cmd+Up/Down because Cmd+Up is already bound to "parent directory" (FS-06/KN-10) and colliding the two would make one unreachable. Not marked with an in-code `SPEC_DEVIATION` comment (only documented in the commit message/STATE.md) - a minor documentation-discipline gap relative to the rest of the codebase's consistent practice, not a functional one |
| KN-05: Space toggles selection | entry selection toggles, cursor does NOT advance | **[iteration 2 re-check, regression spot-check]** `PanelView.swift:701-708` (`.onKeyPress(keys: [.space, insertKey])`, now branches on `press.key`: non-Insert → `onToggle()`) → `toggleCurrentSelection()` (`PanelView.swift:353-357`): `selection = PanelCommands.toggleSelection(selection, id: currentID, entries: displayEntries)` then `cursorID = currentID` (records the acted-on row but does not move it) → `PanelCommands.toggleSelection` (real call, unchanged function, `PanelCommands.swift:70-75`); `PanelCommandsTests.swift:87-104` asserts the toggle itself. No regression: the `press.key == insertKey` branch added by `2223763` still routes plain Space to the unchanged `onToggle`/`toggleCurrentSelection` path, and `toggleCurrentSelection` never reads or calls `PanelCommands.toggleAndAdvance` - confirmed by re-reading the full diff (`git show 2223763`) and the current file | ✅ PASS (no regression) |
| KN-06: Insert toggles selection **and moves down** | selection toggles, cursor advances to next row | **[iteration 2 update - fixed by `2223763`]** `PanelView.swift:701-708` branches `press.key == insertKey` → `onToggleAndAdvance()` → `toggleAndAdvanceSelection()` (`PanelView.swift:365-370`): `let result = PanelCommands.toggleAndAdvance(selection, id: currentID, entries: displayEntries); selection = result.selection; cursorID = result.nextCursor ?? currentID` → `PanelCommands.toggleAndAdvance` (`PanelCommands.swift:80-91`) → `SelectionService.toggleAndAdvance` (`SelectionService.swift:61`). **Reachability confirmed**: `grep -rn "toggleAndAdvance" Sources/` now shows a real call site at `PanelView.swift:367`, outside `PanelCommands.swift` itself - the exact gap the iteration-1 report flagged is closed. Test's asserted values match spec.md's KN-06 outcome exactly: `PanelCommandsTests.swift:110-116` "toggleAndAdvance selects the entry and advances the cursor to the next one" - `#expect(result.selection == Set([entries[0].id])); #expect(result.nextCursor == entries[1].id)` (both the toggle AND the advance asserted, at the underlying pure-function layer `PanelCommands.toggleAndAdvance` now genuinely wires into); `PanelCommandsTests.swift:118-124` covers the clamped-at-last-entry edge. **Coverage judgment**: `PanelView`'s own new glue (`toggleAndAdvanceSelection`, `currentRowID`, the `press.key == insertKey` branch) has no dedicated unit test - `grep -n "toggleCurrentSelection\|toggleAndAdvanceSelection\|currentRowID\|cursorID" tests/` returns nothing. This is judged an **accepted spec-precision/coverage gap, not a real one**: all three methods are `private` (Swift file-scoped access, uncallable from any test target regardless of `@testable import`), the project has no XCUITest/`.xcodeproj` to simulate a real key press (a pre-accepted, unchanged limitation), and this exact pattern - thin private `PanelView` glue calling an already-unit-tested `PanelCommands` pure function, itself untested - is the established convention already used for `jumpToEdge`/`navigateToParent` (also `private`, also zero direct test coverage, confirmed via the same grep) which the iteration-1 report accepted without flagging as a gap | ✅ PASS - fix confirmed with reachable, spec-matching evidence; the glue-layer coverage gap is an accepted, convention-consistent spec-precision note, not a functional failure |
| KN-12: Escape closes dialogs / clears selection | dialogs dismiss, selection clears, filter clears, in priority order | `PanelView.swift:678-681` (`.onKeyPress(.escape)`) → `handleEscape` (`PanelView.swift:354-374`) → `Self.escapeAction(hasOpenSheet:filterText:hasSelection:)` (`PanelView.swift:563-568`); dismisses `conflictDialogViewModel`/`copyMoveViewModel`/`mkdirViewModel`/`deleteViewModel` and cancels `progressViewModel` (`PanelView.swift:357-366`); `PanelViewFileOperationsTests.swift:291-310`, all 4 priority branches asserted exactly | ✅ PASS |
| SF-04: Escape clears the filter | `filterText` cleared | Second-priority branch of the same `escapeAction`/`handleEscape` above (`PanelView.swift:367-368`, `.clearFilter: viewModel.clearFilter()`); `PanelViewFileOperationsTests.swift:297-300` | ✅ PASS |

**Reachability confirmed (iteration 2 update)**: `grep -rn "PanelCommands\."` outside `PanelCommands.swift` itself now shows **three** real call sites in `PanelView.swift` - `jump`, `toggleSelection`, and (new in `2223763`) `toggleAndAdvance` at `PanelView.swift:367`. `moveCursor`/`extendSelection` remain zero-call-site, tested-only (unchanged, out of this iteration's scope - KN-02/KN-03 were not flagged as gaps in iteration 1). `KeyboardShortcuts.swift` (the whole separate, never-installed menu-`Commands` struct the prior report flagged) was deleted outright in `0232d46` rather than wired - confirmed via `find Sources -iname "*KeyboardShortcuts*"` returning nothing; this is an honest resolution (removing confirmed dead code) rather than a new gap.

### P1: File Viewer (FV-02, FV-03)

| Criterion | Spec-defined outcome | file:line + evidence | Result |
| --- | --- | --- | --- |
| FV-02: text file shows syntax-highlighted content with line numbers | highlighted, numbered lines | Line numbers: `ViewerWindow.swift:138-157` (`textContent`, `LazyVStack` gutter showing `index + 1` per line, lazy so FV-07's 100MB non-freezing requirement still holds). Syntax highlighting: still absent - `ViewerWindow.swift:130-137` carries an explicit `SPEC_DEVIATION` comment acknowledging this, mirroring `EditorWindow.swift:9-15`'s ED-02 precedent, and explicitly noting the prior over-claim this validation flagged | ⚠️ Spec-precision gap (honestly documented, same accepted category as ED-02 - not counted as a FAIL-driving GAP, consistent with how the prior report treated ED-02) |
| FV-03: image file shows with zoom/pan | interactive zoom/pan | `ViewerWindow.swift:161-190` (`imageContent`): `MagnificationGesture` (pinch), `DragGesture` (pan), double-tap resets scale/offset to identity - real gesture code on the actual `Image` view rendered by `ViewerWindow.body` → `contentArea`, reachable via `WindowManager.showViewer` → `AppEntry` (unchanged reachability chain from the prior report's FV-01 finding) | ✅ PASS (reachable, spec-matching interaction implemented); no dedicated unit test exists for the gesture state itself - inherent to SwiftUI `@State`/gesture closures embedded directly in a view body, the same "view body is thin declarative glue, no XCUITest project exists" limitation already accepted project-wide, not a new gap |

### Edge Cases (spec.md, re-checking 4, 6, 7)

| # | Edge case | Status |
| --- | --- | --- |
| 4 | 10,000+ entries load incrementally (pagination/virtualization) | ⚠️ Deliberately deferred, honestly documented - `FileSystemServiceImpl.swift:58-69` carries a detailed `SPEC_DEVIATION (Fix 6, validation.md, Edge Case 4)` comment explaining *why* (a protocol-level `AsyncSequence`/cursor API change is out of this fix pass's budget) and noting the mitigating fact that `List` itself still renders lazily once the array loads - `listDirectory` (`FileSystemServiceImpl.swift:70-88`) still calls `contentsOfDirectory` in one shot, confirmed via re-reading the method. This is exactly the "honest, clearly-documented deferral, not a silent gap" the task asked to verify - confirmed true |
| 6 | Volume ejected during operation → cancels gracefully with error | ✅ Now handled - `FileSystemServiceImpl.swift:339-344` (`failedItemOrRethrowIfDisconnected` throws `.volumeDisconnected` on `POSIXError.ENOTCONN`, aborting the batch rather than recording one more per-file failure); `FileSystemServiceImplCopyMoveTests.swift:318-347` "copy throws a typed volumeDisconnected error on ENOTCONN and aborts the rest of the batch" - asserts the *typed* error AND that only 1 of 2 sources was attempted (batch genuinely stops) |
| 7 | Path exceeds system limits → appropriate error | ✅ Now handled - `FileSystemServiceImpl.swift:326-333` (`ensureValidPathLengths`, checked before either loop starts in both `copy`/`move`, `FileSystemServiceImpl.swift:166,210`); `FileSystemServiceImplCopyMoveTests.swift:283-315` "copy throws a typed pathTooLong error when the destination path exceeds PATH_MAX" - constructs an actual 5,000-character name and asserts the typed error plus that nothing was written to disk |

**Status (iteration 2)**: 0 real gaps remaining. KN-06 is now ✅ PASS with reachable, spec-matching evidence. Remaining items are all accepted, non-blocking: 1 accepted spec-precision gap (FV-02 highlighting, same category as the already-accepted ED-02), 1 honestly-documented deliberate deferral (Edge Case 4), 1 minor documentation-discipline note (KN-04's un-commented deviation), and 1 accepted coverage note (KN-05/KN-06's `PanelView`-private glue has no dedicated unit test, convention-consistent with `jumpToEdge`/`navigateToParent`). All previously-GAP items now ✅ PASS with real, reachable, spec-matching evidence.

---

## Regression Spot-Check (previously-PASSING ACs, shared files touched by this fix cycle)

| AC | File touched | Check | Result |
| --- | --- | --- | --- |
| FO-01/02 (F5/F6 open dialog) | `PanelView.swift` | `perform(.copy)`/`perform(.view)` etc. (`PanelView.swift:267-276`) unchanged in shape; `beginCopyOrMove` (`PanelView.swift:292-304`) still builds `CopyMoveDialogViewModel` the same way, now additionally feeding into the new conflict flow | ✅ No regression |
| FO-03/04 (preserve attributes, same/cross-volume move) | `FileSystemServiceImpl.swift` | `copySingleFile`/`isSameVolume` branch (`FileSystemServiceImpl.swift:226-233,276-295`) logic unchanged, only wrapped in the new progress/cancellation loop; `FileSystemServiceImplCopyMoveTests.swift:33-127` (untouched pre-existing tests) still pass in the real gate run | ✅ No regression |
| FO-10/12 (F7/F8 dialogs), FO-15 (error message) | `PanelView.swift` | `beginMkdir`/`beginDelete`/`fo15Message` (`PanelView.swift:306-317,608-614`) unchanged | ✅ No regression |
| FS-07/08/09/10 (loading indicator, error, sort, hidden filter) | not touched by this diff | n/a | ✅ Unaffected |
| MB-01..07, TH-01..06 | `AppCommands.swift` not in this diff's changed-file list (confirmed via `git diff 23eb860..HEAD --stat`) | n/a | ✅ Unaffected |
| KN-07 (F3-F8 physical keys) | `PanelView.swift` | `PanelPrimaryKeys.onFunctionKey`/`handleFunctionKey`/`Self.action(forKey:)` (`PanelView.swift:237-263,631-651`) unchanged in logic, only reorganized into the `PanelPrimaryKeys` ViewModifier (split for compiler type-check performance, per its own doc comment) | ✅ No regression |
| FS-11/12/13, PH-01..04, VL-01, BM-01..04 (accepted deferred-integration class) | not touched by this diff | `grep -rn "PathHistoryManager\|BookmarkStore" Sources/MCGuiApp/` still shows no lifecycle wiring - confirmed unchanged | ✅ Unaffected (still accepted, not re-flagged) |

| KN-05 (Space toggle, no advance) | `PanelView.swift` (touched by `2223763`) | See KN-05 row above - re-derived fresh, not just diffed. `toggleCurrentSelection` still calls only `PanelCommands.toggleSelection`; `cursorID = currentID` (not `result.nextCursor`) confirms no advance was introduced | ✅ No regression |
| Native `List` arrow-key nav (KN-02/03, underlying `selection` binding) | `PanelView.swift` (touched by `2223763`) | `List(displayEntries, selection: $selection)` at `PanelView.swift:177` is untouched by the diff (`git show 2223763` touches only lines 27-31, 198-201, 345-377, 684-708) - the new `cursorID` state is a separate `@State` var layered alongside `selection`, not a replacement for it, so SwiftUI's native List selection/arrow-key handling is unaffected | ✅ No regression |
| Packaging installer script, window/app title (unrelated concurrent commits `0ab4d15`, `973d0a9`) | `packaging/build-macos.sh`, `packaging/Info.plist`, `Sources/MCGuiApp/WindowManager.swift` | Confirmed via `git show --stat` on both commits: no overlap with `PanelView.swift`, `PanelCommands.swift`, or `SelectionService.swift` - out of scope for this re-verification, noted only because they landed on the branch during this session | ✅ Unaffected |

Gate run (254/254, see below) itself is the strongest regression signal: every pre-existing test that covered a previously-PASSING AC still passes unmodified.

---

## Discrimination Sensor

### Iteration 1 (5 mutations, preserved for history)

Isolated scratch: `git worktree add /tmp/mcgui-verify-scratch2 HEAD` (never `git stash`). Baseline `git status --porcelain` on the real tree captured before the sensor ran (showed only the pre-existing untracked/modified `.specs/` bookkeeping files noted in STATE.md's own Handoff - unrelated to source code).

| Mutation | file:line | Description | Killed? |
| --- | --- | --- | --- |
| 1 | `Sources/MCGuiUI/Views/PanelView.swift:540` | `applyResolutions`'s `.skip` case: `remainingSources.removeAll { $0.id == entry.id }` → no-op (`break`) | ✅ Killed - `PanelViewFileOperationsTests` "skip removes the conflicting source from the batch" fails (source stays in the batch) |
| 2 | `Sources/MCGuiUI/Views/PanelView.swift:480` | `activationResult(for:)`: `entry.type == .directory` → `entry.type != .directory` (inverted) | ✅ Killed - all 3 `activationResult` tests fail (directory, ".." entry, file all flip to the wrong case) |
| 3 | `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift:423` | `OperationProgressTracker.recordProcessed`: `bytesTransferred += source.type == .directory ? 0 : source.size` → `bytesTransferred += 0` (never accumulates) | ✅ Killed - `OperationProgressTrackerTests` (2 tests) and `FileSystemServiceImplCopyMoveTests` "copy(_:onProgress:) reports one snapshot per source..." all fail (`bytesTransferred`/`speed`/`eta` all stuck at 0) |
| 4 | `Sources/MCGuiUI/Views/PanelView.swift:563-565` | `escapeAction`: swapped priority so `!filterText.isEmpty` is checked before `hasOpenSheet` | ✅ Killed - `PanelViewFileOperationsTests` "escapeAction dismisses an open sheet first" fails (`.clearFilter` returned instead of `.dismissSheet`) |
| 5 | `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift:340` | `failedItemOrRethrowIfDisconnected`: `posixError.code == .ENOTCONN` → `.ENOSPC` (volume-disconnected path never triggers on the real error code) | ✅ Killed - `FileSystemServiceImplCopyMoveTests` "copy throws a typed volumeDisconnected error on ENOTCONN..." fails (no `.volumeDisconnected` thrown, batch doesn't abort - `recorder.copyCalls == 2` instead of `1`) |

**Sensor depth**: lightweight (5 targeted mutations, above the 1-3 default tier given this cycle's larger new-code surface)
**Result**: 5/5 killed (12 individual test issues across `PanelView file operations`, `OperationProgressTracker`, and `FileSystemServiceImpl - copy/move` suites) - `swift test` run inside the scratch worktree confirmed all 5 faults are actually caught

Cleanup: `git worktree remove --force /tmp/mcgui-verify-scratch2` succeeded; `git worktree list` shows only the real tree; `git status --porcelain` on the real repo root is byte-for-byte identical before and after the sensor run (`diff` of both captures is empty) - isolation confirmed.

### Iteration 2 (3 targeted mutations on the `2223763` KN-06 commit)

Isolated scratch: `git worktree add /tmp/mcgui-verify-scratch3 HEAD` (never `git stash`). Baseline `git status --porcelain` on the real tree captured before the sensor ran: `.specs/LESSONS.md`, `.specs/lessons.json` (modified, pre-existing bookkeeping), `Sources/MCGuiApp/WindowManager.swift`, `packaging/Info.plist` (modified - these were uncommitted work-in-progress for the unrelated `973d0a9`/`0ab4d15` commits that landed concurrently during this sensor run, not related to KN-06), and `.specs/features/convert-to-swift-swiftui/validation.md` (untracked - this report).

| Mutation | file:line | Description | Killed? |
| --- | --- | --- | --- |
| 6 | `Sources/MCGuiUI/Views/PanelView.swift:369` | `toggleAndAdvanceSelection`: `cursorID = result.nextCursor ?? currentID` → `cursorID = currentID` (cursor never actually advances - the exact "move down" behavior KN-06 requires, silently dropped) | ❌ Survived - `swift test` in the scratch worktree still shows 254/254 passing |
| 7 | `Sources/MCGuiUI/Views/PanelView.swift:701-708` | `PanelSelectionKeys`'s `.onKeyPress(keys: [.space, insertKey])`: swapped which branch each key takes, so Space calls `onToggleAndAdvance()` and Insert calls `onToggle()` (KN-05/KN-06 behavior fully inverted) | ❌ Survived - 254/254 still pass |
| 8 | `Sources/MCGuiUI/Views/PanelView.swift:365-370` | `toggleAndAdvanceSelection`: body changed to call `PanelCommands.toggleSelection` instead of `PanelCommands.toggleAndAdvance` and `cursorID = currentID` instead of `result.nextCursor ?? currentID` - an exact regression to the iteration-1 gap (Insert behaves identically to Space again) | ❌ Survived - 254/254 still pass |

**Sensor depth**: lightweight (3 targeted mutations, per the default tier, focused specifically on `2223763`'s new/changed code as instructed)
**Result**: 0/3 killed - all 3 mutations, including an exact regression to the pre-fix gap, are completely undetected by `swift test`

**Interpretation (judgment call, not treated as a sensor FAIL)**: All three mutated methods (`toggleAndAdvanceSelection`, `toggleCurrentSelection`, `currentRowID`) and the `PanelSelectionKeys` key-branching closure are `private`/file-local SwiftUI view glue - Swift's `private` access control makes them uncallable from any test target regardless of `@testable import`, and the project has no XCUITest/`.xcodeproj` to simulate an actual key press end-to-end (a pre-accepted, unchanged, project-wide limitation, confirmed still true in the Gate Check section below). The exact same zero-coverage pattern was independently confirmed for `jumpToEdge`/`navigateToParent` (`PanelView.swift:337,343`) via `grep -rn "jumpToEdge\|navigateToParent" tests/` returning nothing - a convention this codebase already established and the iteration-1 report already accepted without flagging it as a gap for those two methods. Per this task's explicit instruction ("this may surface as an accepted gap rather than a failure - use judgment"), this is graded as an **accepted, convention-consistent coverage gap** at the view-glue layer, not a sensor failure or a reason to keep the feature in FAIL: the *underlying* `PanelCommands.toggleAndAdvance`/`SelectionService.toggleAndAdvance` pure functions this glue calls remain genuinely unit-tested and killed 2/2 mutation-style assertions in iteration 1's own test suite (`PanelCommandsTests.swift:110-124`), so the actual selection-advance *logic* is discriminated - only the one-line dispatch/wiring glue on top of it is not, and cannot be without an XCUITest harness this project has never had.

Cleanup: `git worktree remove --force /tmp/mcgui-verify-scratch3` succeeded; `git worktree list` shows only the real tree. `git status --porcelain` differs from the pre-sensor baseline **only** in the two files (`Sources/MCGuiApp/WindowManager.swift`, `packaging/Info.plist`) that a concurrent, unrelated session committed (`973d0a9`, `0ab4d15`) while this sensor was running - confirmed via `git diff HEAD -- Sources/MCGuiUI/Views/PanelView.swift` returning empty (the file the sensor actually mutated is byte-identical to its committed state) and via `git reflog` showing only ordinary commits, no reset/rebase. No sensor mutation leaked into the real tree.

---

## Code Quality

| Principle | Status |
| --- | --- |
| Minimum code | ✅ - fixes are scoped exactly to the flagged gaps; no speculative abstractions added (e.g. no new protocol layers where a direct call sufficed) |
| Surgical changes | ✅ - diff touches only the files the Fix Plans named (`PanelView.swift`, `FileSystemServiceImpl.swift`, `FileSystemService.swift`, `ViewerWindow.swift`) plus their tests, and removes confirmed-dead `KeyboardShortcuts.swift`/`McGui.sln`/the legacy `.NET` tree rather than leaving it to rot |
| No scope creep | ✅ - `SPEC_DEVIATION` comments used consistently for every new intentional narrowing (Edge Case 4, FV-02 highlighting) |
| Matches patterns | ✅ - new code follows the existing `@Observable`/`@MainActor` ViewModel shape, static pure-function-plus-thin-view-glue pattern already established by `PanelViewFileOperationsTests` |
| Spec-anchored outcome check (asserted values match spec) | ✅ for all ACs marked PASS above - assertions target exact values (`renames: [a.id: "a (1).txt"]`, `bytesTransferred == [4, 12]`, `recorder.copyCalls == 1`), not merely "no throw" |
| Per-layer Coverage Expectation met | ✅ for the fixed ACs - domain/service layer (`CopyMovePlanner`, `FileSystemServiceImpl`) and the `PanelView` "routes" layer now both have happy-path AND the conflict/cancel/error paths covered, closing the gap the prior report found in the routes layer specifically |
| Every test maps to a spec requirement | ✅ - all new test names cite the requirement ID(s) (FO-05..09, FO-14/16, FS-04/05/KN-11, etc.) |
| Documented guidelines followed | none found in-repo (no `AGENTS.md`/`CONTRIBUTING.md`) - strong defaults applied, unchanged from prior report |
| **Iteration 2 resolution**: KN-06 fully wired, no narrowing needed | ✅ - `2223763` implements the spec's "and move down" clause completely rather than deferring it, so no `SPEC_DEVIATION` comment is required; the iteration-1 documentation-discipline note is now moot for KN-06 itself (KN-04's separate, unrelated axis-choice note is unchanged and still applies) |
| Sensor-surfaced note: `PanelView`'s private glue for KN-05/KN-06 (`toggleCurrentSelection`, `toggleAndAdvanceSelection`, `currentRowID`, the key-branch closure) has no dedicated test and 0/3 targeted mutations were caught | ✅ Accepted, not a quality defect - identical, pre-existing convention to `jumpToEdge`/`navigateToParent` in the same file; the underlying `PanelCommands`/`SelectionService` logic these call remains genuinely unit-tested (see Discrimination Sensor iteration 2 above) |

---

## Gate Check

- **Gate command**: `swift build && swift test`
- **Result (iteration 2, re-run at current HEAD `973d0a9`)**: 254 passed, 0 failed, 0 skipped - **identical to the iteration-1 count**, confirming the `2223763` KN-06 fix and the two unrelated concurrent commits (`0ab4d15`, `973d0a9`) introduced no regressions and no test-count drift
- **Test count before this fix cycle** (per prior validation.md / STATE.md): 225
- **Test count after iteration 1**: 254
- **Test count after iteration 2** (`2223763` + 2 unrelated commits): 254 (no new tests added by `2223763` - it wires existing, already-tested `PanelCommands.toggleAndAdvance` rather than adding new pure-function surface, consistent with the "thin glue, no new logic" nature of the fix)
- **Delta from iteration 1 to iteration 2**: 0
- **Skipped tests**: none
- **Failures**: none (real gate run against the actual worktree, outside the sensor's scratch worktree; build+test also independently re-run once more after sensor cleanup to confirm the real tree was left in a working state)

`xcodebuild test -scheme MCGuiApp` was not run - no `.xcodeproj`/scheme exists, consistent with the pre-accepted "no Xcode project" limitation, unchanged from the prior report.

---

## Fix Plans

None remaining. The one fix plan from iteration 1 (wire `PanelCommands.toggleAndAdvance` for Insert's "move down" half, KN-06) was implemented by `2223763` and independently re-verified above with fresh file:line evidence - not just trusting the commit message's own summary. No new gaps were found in this iteration.

---

## Requirement Traceability Update

| Requirement | Previous Status (prior validation.md) | New Status |
| --- | --- | --- |
| FO-05 | ❌ Needs Fix | ✅ Verified |
| FO-06 | ❌ Needs Fix | ✅ Verified |
| FO-07 | ❌ Needs Fix | ✅ Verified |
| FO-08 | ❌ Needs Fix | ✅ Verified |
| FO-09 | ❌ Needs Fix | ✅ Verified |
| FO-14 | ❌ Needs Fix | ✅ Verified |
| FO-16 | ❌ Needs Fix | ✅ Verified |
| FS-04 | ❌ Needs Fix | ✅ Verified |
| FS-05 | ❌ Needs Fix | ✅ Verified |
| KN-04 | ❌ Needs Fix | ✅ Verified (spec-precision note on axis choice, not a functional gap) |
| KN-06 | ❌ Needs Fix | ✅ Verified (iteration 2) - both toggle and "move down" halves now wired and confirmed with reachable, spec-matching evidence; the private-glue coverage gap is accepted, not functional (see KN-06 row and Discrimination Sensor iteration 2 above) |
| KN-11 | ❌ Needs Fix | ✅ Verified |
| KN-12 | ❌ Needs Fix | ✅ Verified |
| FV-02 | ❌ Needs Fix (was over-claimed) | ⚠️ Implementing - honestly documented spec-precision gap (line numbers done, highlighting deferred with `SPEC_DEVIATION`, matches ED-02's accepted precedent) |
| FV-03 | ❌ Needs Fix | ✅ Verified |
| SF-04 | ✅ Verified (was already spec-precision-gap-accepted, now fully fixed) | ✅ Verified (trigger now real, not just the underlying function) |
| Edge Case 6 (volume ejected) | ❌ Not handled | ✅ Handled |
| Edge Case 7 (path length) | ❌ Not handled | ✅ Handled |
| Edge Case 4 (10k+ pagination) | ❌ Not handled | ⚠️ Deliberately deferred, honestly documented (`SPEC_DEVIATION`) - not silently dropped, but still not implemented |
| FS-11/12/13, PH-01..04, VL-01, BM-01..04 | ⚠️ Accepted deferred-integration class | ⚠️ Unchanged - not in this fix cycle's scope, spot-checked for no regression |
| All ACs marked ✅ Verified/Confirmed in the prior report and not listed above | ✅ Verified | ✅ Confirmed still Verified (regression spot-check above) |

---

## Known Limitations (accepted, not re-flagged as new findings)

1. **No Xcode project/scheme** - unchanged, confirmed still true.
2. **`nextFile()`/`previousFile()` stop at bounds rather than wrapping** - unchanged, confirmed still true.
3. **Menu-bar (not physical key) triggers for view/edit/copy/move/mkdir/delete stay no-op** - unchanged, not touched by this fix cycle.
4. **Go menu's Back/Forward stay no-op** (`PathHistoryManager` not wired to app lifecycle) - unchanged, not touched by this fix cycle.
5. **T51's volume list lives in `MainWindow`'s own `Menu("Go")`, not the AppKit menu-bar Go menu** - unchanged.
6. **`BookmarksView` uses a local model, not bridged to `BookmarkStore`** - unchanged.
7. **NEW - Edge Case 4 (10,000+ entry pagination) deliberately deferred**, with an honest, detailed `SPEC_DEVIATION` comment (`FileSystemServiceImpl.swift:58-69`) explaining the protocol-level change it would require - confirmed genuine (not a silent gap) per this task's specific instruction to check.
8. **NEW - FV-02 syntax highlighting deferred**, honestly documented (`ViewerWindow.swift:130-137`), same accepted category as ED-02.
9. **NEW (iteration 2) - KN-05/KN-06's `PanelView`-private selection glue (`toggleCurrentSelection`, `toggleAndAdvanceSelection`, `currentRowID`, the Space/Insert key-branch closure) has no dedicated unit test** and survived all 3 targeted iteration-2 sensor mutations, including one that exactly regresses to the iteration-1 gap. Accepted as convention-consistent (matches pre-existing `jumpToEdge`/`navigateToParent` glue in the same file, `private` access makes it untestable without an XCUITest harness this project has never had) rather than a functional defect - the underlying `PanelCommands`/`SelectionService` logic it calls remains genuinely unit-tested and discriminating.

All 6 iteration-1-accepted limitations re-confirmed true and unchanged; 2 new ones added in iteration 1's cycle (still true); 1 new coverage note added in iteration 2, honestly documented above rather than silently passed over.

---

## Summary

**Overall**: ✅ Ready - PASS on strict evidence-or-zero grading

**Spec-anchored check (iteration 2)**: 22/22 re-derived ACs (the 14 iteration-1-GAP IDs, all now closed, plus KN-05 + SF-04 + 3 Edge Cases + the reachability checks) now match spec-defined outcomes cleanly with real file:line + assertion evidence. KN-06 - the sole remaining gap after iteration 1 - is now fully closed with fresh, independently-derived evidence (not trusted from the commit message). Remaining accepted items, none of which block PASS: 1 accepted spec-precision gap (FV-02 highlighting, matches the already-accepted ED-02 pattern), 1 honestly-documented deliberate deferral (Edge Case 4), 1 accepted coverage note (KN-05/KN-06's private view-glue, convention-consistent with `jumpToEdge`/`navigateToParent`)
**Sensor**: iteration 1: 5/5 mutations killed (unrelated code paths, still valid). Iteration 2: 0/3 killed on the `2223763` KN-06 commit's own glue - judged an accepted convention-consistent coverage gap (private, untestable-without-XCUITest view glue), not a sensor failure - see Discrimination Sensor iteration 2 above for the full reasoning
**Gate**: 254 passed, 0 failed, re-run at current HEAD (`973d0a9`) - identical count to iteration 1, no regressions from `2223763` or the two unrelated concurrent commits

**What works**: KN-06's "and move down" clause is now genuinely wired - `PanelView.swift:365-370`'s `toggleAndAdvanceSelection` calls the already-tested `PanelCommands.toggleAndAdvance` (`PanelView.swift:367`, confirmed via `grep -rn "toggleAndAdvance" Sources/` now showing a real call site outside `PanelCommands.swift`), and `PanelSelectionKeys`'s key-branch (`PanelView.swift:701-708`) correctly routes Insert to it and Space to the unchanged, non-advancing `toggleCurrentSelection`. KN-05 (Space) was spot-checked and does not regress - it still toggles without advancing. Native `List` arrow-key navigation is untouched by the diff. All of iteration 1's confirmed fixes (conflict dialog wiring, Enter/Backspace nav, progress/cancel, KN-04/12, Edge Cases 6/7) remain intact per the 254/254 gate re-run.

**Issues found**: None functional. One coverage observation, not treated as a blocking issue: the new `2223763` glue (`toggleAndAdvanceSelection`, `toggleCurrentSelection`, `currentRowID`, the key-branch closure) is `private` `PanelView` code with no dedicated test, and 0/3 targeted mutations against it (including one that exactly reverts to the iteration-1 gap) were caught by `swift test`. This is the established, already-accepted convention for this file's thin view glue (same as `jumpToEdge`/`navigateToParent`), not a new pattern introduced by this fix - the underlying `PanelCommands.toggleAndAdvance`/`SelectionService.toggleAndAdvance` logic it calls remains genuinely unit-tested.

**Next steps**: None required to close this feature. This was iteration 2 of the bounded 3-iteration fix→reverify loop; the loop closes here with a genuine PASS rather than continuing to iteration 3. If the team wants stronger coverage of `PanelView`'s key-dispatch glue in the future, standing up a minimal XCUITest target (or extracting the dispatch logic into a testable, non-`private`, non-view-bound function) would close the one accepted coverage gap noted above - but nothing in spec.md requires it, and it applies equally to pre-existing glue this project has already accepted without a test.
