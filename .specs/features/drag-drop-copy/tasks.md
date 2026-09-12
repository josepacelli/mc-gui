# Drag-and-Drop Copy Between Panels Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/drag-drop-copy/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Generated from codebase sampling (`Tests/MCGuiUITests/**`, `PanelViewFileOperationsTests.swift`'s static-helper pattern) and the CI workflow (`.github/workflows/tests.yml`: `swift build` + `swift test`). No `AGENTS.md`/`CONTRIBUTING.md` found - strong defaults applied. This matrix is shared verbatim with the sibling `context-menu-actions/tasks.md` since both features live in the same package/test setup.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| `MCGuiUI` pure/static helpers (e.g. `PanelView.dragPayload`, `.resolveDroppedEntries`, `.shouldIgnoreDrop`) | unit | 1:1 to spec ACs; every listed edge case has a test - matches the existing `PanelView.targetEntry`/`makeCopyMoveDialog` static-testable-helper pattern in `PanelViewFileOperationsTests.swift` | `Tests/MCGuiUITests/Views/PanelViewFileOperationsTests.swift` (extended) | `swift test --filter PanelViewFileOperationsTests` |
| New model types (`DraggedFileURLs`) | unit | Codable round-trip + field correctness | `Tests/MCGuiUITests/Models/DraggedFileURLsTests.swift` | `swift test --filter DraggedFileURLsTests` |
| `MCGuiUI` SwiftUI views (`.draggable`/`.dropDestination` wiring, gesture coexistence with click/double-click/right-click) | none | Interactive UAT only - this repo has no view-body test anywhere today (confirmed: no test file targets `FileRow.swift`, `ProgressDialog.swift`, etc.) | n/a | manual verification during Execute |
| `MCGuiUI` view-model property additions (`PanelViewModel.instanceID`) | none | Entity/trivial-property tier - build gate only | n/a | `swift build` |

## Gate Check Commands

> Generated from `.github/workflows/tests.yml` (`swift build` then `swift test`, no lint step configured in this repo per `CLAUDE.md`).

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After a task with a new/extended unit-test suite | `swift test --filter <SuiteName>` |
| Full | After the last task of a phase, or any task touching shared state (`PanelView.swift`) | `swift test` |
| Build | After a task with no new tests (interface-only or trivial property) | `swift build` |

---

## Execution Plan

Single batch - 6 tasks total, at the ≤8 inline-execution threshold. No sub-agent dispatch needed.

### Phase 1: Foundation

T1 and T4 have no dependencies (run in task-list order, first and third in the phase). T2 → T3.

```
T2 -> T3
```

### Phase 2: Drop Handling Integration

T5 depends on T1, T3, and T4 (all from Phase 1). T6 depends on T5.

```
T1 -> T5
T3 -> T5
T4 -> T5
T5 -> T6
```

---

## Task Breakdown

### T1: Add `PanelViewModel.instanceID` ✅ Done

**What**: Add `public let instanceID = UUID()` to `PanelViewModel`, giving each panel a stable identity a drop handler can compare against.
**Where**: `Sources/MCGuiUI/ViewModels/PanelViewModel.swift`
**Depends on**: None
**Reuses**: N/A - new trivial property
**Requirement**: DND-08 (enables same-panel detection used by T5)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `PanelViewModel.instanceID: UUID` exists, initialized once per instance
- [ ] `swift build` succeeds

**Tests**: none (trivial property, entity tier)
**Gate**: build

---

### T2: Add `DraggedFileURLs` Transferable type ✅ Done (file at `Sources/MCGuiUI/Views/DraggedFileURLs.swift`, matching this module's existing folder convention — no `Models/` folder exists in `MCGuiUI`)

**What**: New `Codable`, `Transferable` struct wrapping `sourcePanelID: UUID` and `paths: [URL]`, using `CodableRepresentation(contentType: .json)` per the design's confirmed SDK usage.
**Where**: `Sources/MCGuiUI/Models/DraggedFileURLs.swift` (new file)
**Depends on**: None
**Reuses**: N/A - new type
**Requirement**: DND-01, DND-06 (drag payload shape)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `DraggedFileURLs: Codable, Transferable` compiles against the project's SwiftUI/CoreTransferable imports
- [ ] A round-trip test (`JSONEncoder`/`JSONDecoder`) confirms `sourcePanelID` and `paths` survive encode/decode unchanged
- [ ] `swift test --filter DraggedFileURLsTests` passes

**Tests**: unit
**Gate**: quick

---

### T3: Add `PanelView.dragPayload(for:)` and wire `.draggable` ✅ Done

**What**: A static, testable function `PanelView.dragPayload(for entry: FileEntry, markedIDs: Set<UUID>, markedEntries: [FileEntry], sourcePanelID: UUID) -> DraggedFileURLs` returning the marked set's paths if `entry.id` is marked, else `[entry.path]` alone; wired onto each row via `.draggable(dragPayload(for: entry))` in `entryList`.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift`
**Depends on**: T2
**Reuses**: `markedIDs`, `markedEntries` (existing, from the prior selection/marks fix)
**Requirement**: DND-01, DND-06

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `dragPayload(for:markedIDs:markedEntries:sourcePanelID:)` returns `[entry.path]` when the entry is not in `markedIDs`
- [ ] `dragPayload(...)` returns every marked entry's path (not just `entry`'s) when the entry IS in `markedIDs`
- [ ] `.draggable` is attached to each row in `entryList` using this function and the panel's own `instanceID`
- [ ] `swift build` succeeds (confirms `.draggable`'s generic constraints resolve against this project's Swift toolchain, per the design's flagged risk)
- [ ] `swift test --filter PanelViewFileOperationsTests` passes

**Tests**: unit
**Gate**: quick

---

### T4: Add `PanelView.resolveDroppedEntries(paths:in:)`

**What**: A static, testable function `PanelView.resolveDroppedEntries(paths: [URL], in entries: [FileEntry]) -> [FileEntry]` filtering a directory listing down to the entries whose `path` is in the dropped set (preserves `entries`' order, ignores any path with no match - e.g. a source deleted mid-drag).
**Where**: `Sources/MCGuiUI/Views/PanelView.swift`
**Depends on**: None
**Reuses**: N/A - new pure helper, same shape as the existing `Self.targetEntry`/`makeCopyMoveDialog` static helpers
**Requirement**: DND-02

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Given paths matching a subset of `entries`, returns exactly the matching `FileEntry` values
- [ ] Given a path with no match in `entries`, that path is silently skipped (no crash, no placeholder entry)
- [ ] Given an empty `paths` array, returns `[]`
- [ ] `swift test --filter PanelViewFileOperationsTests` passes

**Tests**: unit
**Gate**: quick

---

### T5: Add `PanelView.shouldIgnoreDrop(...)` and `handleDrop(_:)`

**What**: A static, testable guard `PanelView.shouldIgnoreDrop(sourcePanelID: UUID, destinationPanelID: UUID, hasRunningOperation: Bool) -> Bool` (true when source == destination, or an operation is already running); an async `handleDrop(_ payload: DraggedFileURLs)` that applies this guard, resolves dropped paths via `fileSystemService.listDirectory(parent)` + `resolveDroppedEntries` (T4), and opens the copy dialog via the existing `Self.makeCopyMoveDialog(selection:mode:destinationDirectory:)` with `destinationDirectory: viewModel.currentPath`.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift`
**Depends on**: T1, T3, T4
**Reuses**: `Self.makeCopyMoveDialog`, `operationTask` guard, `fileSystemService.listDirectory`
**Requirement**: DND-02, DND-03, DND-04, DND-05, DND-08, DND-09, DND-12

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `shouldIgnoreDrop` returns `true` when `sourcePanelID == destinationPanelID`, regardless of `hasRunningOperation`
- [ ] `shouldIgnoreDrop` returns `true` when `hasRunningOperation` is `true`, even for two different panel IDs
- [ ] `shouldIgnoreDrop` returns `false` only when panel IDs differ AND no operation is running
- [ ] `handleDrop` opens `copyMoveViewModel` (via the existing sheet state) with `destinationDirectory` equal to the destination panel's `currentPath` when the guard passes
- [ ] `handleDrop` does nothing (no dialog, no state change) when the guard fails
- [ ] `swift test --filter PanelViewFileOperationsTests` passes

**Tests**: unit
**Gate**: quick

**Commit**: `feat(panel): add drag-and-drop copy guard and handler`

---

### T6: Wire `.dropDestination` on `entryList`

**What**: Attach `.dropDestination(for: DraggedFileURLs.self) { items in ... }` to `entryList`, calling `handleDrop` (T5) for the first received item; manually verify (per the design's flagged Risk) that dragging, single-click, double-click, and right-click all still work correctly together on the same row after this change.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift`
**Depends on**: T5
**Reuses**: `handleDrop` (T5)
**Requirement**: DND-01 through DND-05 (end-to-end wiring)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] `.dropDestination(for: DraggedFileURLs.self)` is attached to `entryList` and calls `handleDrop`
- [ ] `swift build` succeeds
- [ ] Manual check in a running build: drag an unmarked file to the other panel, confirm the dialog, see it copied
- [ ] Manual check: mark 2+ files, drag one of them to the other panel, confirm, see all marked files copied
- [ ] Manual check: drag and drop back onto the same panel, confirm nothing happens
- [ ] Manual check: single-click, double-click, and right-click on a row still behave as before this change

**Tests**: none (SwiftUI view wiring; behavior already covered by T1-T5's unit tests, gesture coexistence is interactive-only per the matrix)
**Gate**: build

**Commit**: `feat(panel): wire drag-and-drop copy between panels`

---

## Phase Execution Map

Phase 1 (T1, T4 standalone; T2 -> T3) runs before Phase 2 (T1, T3, T4 -> T5 -> T6):

```
T2 -> T3
T1 -> T5
T3 -> T5
T4 -> T5
T5 -> T6
```

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: Add `instanceID` | 1 property, 1 file | ✅ Granular |
| T2: `DraggedFileURLs` type | 1 type, 1 file | ✅ Granular |
| T3: `dragPayload` + `.draggable` wiring | 1 function + 1 modifier, 1 file | ✅ Granular |
| T4: `resolveDroppedEntries` | 1 function, 1 file | ✅ Granular |
| T5: `shouldIgnoreDrop` + `handleDrop` | 2 cohesive functions (guard + the one caller that uses it), 1 file | ✅ Granular (2-3 related things in same file, cohesive) |
| T6: `.dropDestination` wiring | 1 modifier + manual check, 1 file | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | Standalone in Phase 1 | ✅ Match |
| T2 | None | Standalone, feeds T3 | ✅ Match |
| T3 | T2 | T2 → T3 | ✅ Match |
| T4 | None | Standalone in Phase 1 | ✅ Match |
| T5 | T1, T3, T4 | T1 → T5, T3 → T5, T4 → T5 | ✅ Match |
| T6 | T5 | T5 → T6 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: `instanceID` | Entity/trivial property | none | none | ✅ OK |
| T2: `DraggedFileURLs` | New model type | unit | unit | ✅ OK |
| T3: `dragPayload` + `.draggable` | Static helper (unit) + SwiftUI view (none) | unit (helper), none (view wiring) | unit | ✅ OK (view wiring's manual confirmation deferred to T6, where the full gesture-coexistence check happens once `.dropDestination` also exists) |
| T4: `resolveDroppedEntries` | Static helper | unit | unit | ✅ OK |
| T5: `shouldIgnoreDrop` + `handleDrop` | Static helper (unit) + async orchestration (none, calls already-tested pieces) | unit | unit | ✅ OK |
| T6: `.dropDestination` wiring | SwiftUI view | none | none | ✅ OK |

---

## Tips

- **Phases are ordered** - Each phase completes before the next; tasks run in order within a phase
- **Reuses = Token saver** - Always reference existing code
- **One commit per task** - Plan the commit message format in advance
