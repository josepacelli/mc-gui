# Drag-and-Drop Copy Between Panels Specification

## Problem Statement

Copying between the two panels today requires marking items and pressing F5. Midnight Commander's dual-pane layout visually invites dragging a file or folder from one panel straight onto the other; the app does not support that yet, forcing a keyboard-only path even when the mouse is already in hand.

## Goals

- [ ] Dragging an item (or the current marked selection) from one panel and dropping it on the other panel starts a copy into that panel's current directory.
- [ ] The copy never starts without an explicit confirmation step naming what will be copied and where.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Move via drag (e.g. Option-drag) | User explicitly scoped this feature to copy only; F6 already covers move via keyboard. |
| Dropping onto a specific sub-row (a folder inside the list) to copy *into* that subfolder | User described panel-to-panel dragging only ("de um lado para o outro"); drop target is always the target panel's current directory, same as F5 today. |
| Cross-app drag (dropping onto Finder, or dragging a Finder item into a panel) | Not requested; scoped to the two in-app panels only. |
| Custom drag preview/thumbnail image | The OS-default drag image is sufficient; no design requirement for a custom one. |
| Copying a folder into itself or one of its own descendants | Pre-existing gap shared with F5 (not introduced by this feature); left as-is. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Confirmation dialog content | Reuse the existing F5 `CopyMoveDialog`/`CopyMoveDialogViewModel` as-is (item count, destination field pre-filled with the target panel's current path, preserve/follow-symlinks/update-only toggles, Cancel/Background/Copy buttons) | User confirmed reusing the existing dialog instead of building a new one; it already shows item count and destination, satisfying "nome dos itens, destino, cancelar/confirmar" | y |
| What gets dragged when the row under the cursor is already marked | Same rule as F5 today: if the dragged row is part of the current marked set, the whole marked set is copied; otherwise only that row is copied | User confirmed matching existing `operationEntries` semantics (marked set with cursor-row fallback) instead of always dragging a single row | y |
| Drop onto the same panel the drag started from | No-op — the drop is ignored, no dialog appears | Feature is specifically inter-panel; same-panel drag-to-copy was never requested and duplicating a file next to itself via drag is not part of this feature | n (undiscussed, logged as default) |
| Conflict handling (destination already has a same-named item) | Reuse the existing `ConflictDialog` flow exactly as F5 uses it today | No new conflict-resolution behavior was requested; F5's flow is already tested and correct | n (undiscussed, logged as default) |
| An operation already running (`operationTask != nil`) | New drag-drop is ignored, same guard F5's `beginCopyOrMove` already uses | Prevents two concurrent filesystem operations on the same panel, consistent with existing F5/F6 behavior | n (undiscussed, logged as default) |
| Drag payload transport | Standard `NSItemProvider`/file-URL drag (SwiftUI `.onDrag`/`.onDrop` or `NSTableView` drag source), resolved back to `FileEntry` values via the destination panel's own `FileSystemService.listDirectory` on drop | Keeps `MCGuiUI` decoupled from a second panel's live view model (panels only know each other's `currentPath` today, per `otherPanelPath`); implementation detail, decided at Design | n/a - implementation detail |

**Open questions:** none - all resolved above (confirmed by user or logged as a reasoned default).

---

## User Stories

### P1: Drag a single file or folder to the other panel ⭐ MVP

**User Story**: As a user browsing two directories side by side, I want to drag a file or folder from one panel and drop it on the other so that I can copy it there without marking it and pressing F5.

**Why P1**: This is the entire feature's reason to exist - the mouse-driven copy path.

**Acceptance Criteria**:

1. WHEN the user starts dragging a row that is not part of the current marked set THEN the system SHALL treat only that row's entry as the drag payload.
2. WHEN the user drops the dragged item on the other panel's file list THEN the system SHALL open the copy confirmation dialog with the destination pre-filled to that panel's current directory and the dragged entry as the only source.
3. WHEN the user confirms the dialog (Copy or Background) THEN the system SHALL perform the copy exactly as pressing F5 with that source/destination does today, including progress reporting and conflict resolution.
4. WHEN the user cancels the confirmation dialog THEN the system SHALL discard the drag with no filesystem change.
5. The system SHALL NOT start any filesystem operation directly on drop - the confirmation dialog SHALL always appear first.

**Independent Test**: Drag a single unmarked file from the left panel onto the right panel, confirm the dialog, and see the file copied into the right panel's directory; drag another file and cancel, and see nothing copied.

---

### P2: Drag the current marked selection

**User Story**: As a user who has already marked several files with Insert/Space, I want dragging any one of the marked rows to carry the whole marked set, so that I don't have to drag each file individually.

**Why P2**: Extends the MVP to the common multi-file case, matching F5's existing behavior for marked selections.

**Acceptance Criteria**:

1. WHEN the user starts dragging a row that IS part of the current marked set THEN the system SHALL treat the entire marked set as the drag payload, not just that row.
2. WHEN that drag is dropped on the other panel THEN the system SHALL open the same confirmation dialog listing the marked set's count as the source.

**Independent Test**: Mark 3 files with Insert, drag any one of the 3 onto the other panel, confirm, and see all 3 copied.

---

### P3: Ignore invalid drop targets

**User Story**: As a user, I want dropping on the same panel I dragged from to simply do nothing, so that an accidental same-panel drop never surprises me with an unwanted copy.

**Why P3**: Safety/polish edge case, not core to the feature's value.

**Acceptance Criteria**:

1. IF the drop target panel is the same panel the drag originated from THEN the system SHALL ignore the drop and SHALL NOT open the confirmation dialog.

**Independent Test**: Drag a file and drop it back onto its own panel's list; nothing happens, no dialog appears.

---

## Edge Cases

- IF a copy/move operation is already running on the destination panel (`operationTask != nil`) THEN the system SHALL ignore the drop, same as F5/F6 already do while an operation is in flight.
- IF the dropped destination already contains an item with the same name THEN the system SHALL show the existing `ConflictDialog` flow, unchanged from F5's current behavior.
- IF the drag is released outside of either panel's file list (e.g., over the button bar or outside the window) THEN the system SHALL NOT open the confirmation dialog.
- WHEN the marked set becomes empty after a drag starts but before it's dropped (e.g., an async load resets marks) THEN the system SHALL fall back to the single row that was under the cursor when the drag began, same fallback `operationEntries` already uses elsewhere.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| DND-01 | P1: Drag a single file/folder | Tasks | Implementing |
| DND-02 | P1: Drag a single file/folder | Tasks | Implementing |
| DND-03 | P1: Drag a single file/folder | Tasks | Implementing |
| DND-04 | P1: Drag a single file/folder | Tasks | Implementing |
| DND-05 | P1: Drag a single file/folder | Tasks | Implementing |
| DND-06 | P2: Drag the marked selection | Tasks | Implementing |
| DND-07 | P2: Drag the marked selection | Tasks | Implementing |
| DND-08 | P3: Ignore invalid drop targets | Tasks | Implementing |
| DND-09 | Edge case: operation already running | Tasks | Implementing |
| DND-10 | Edge case: name conflict at destination | Tasks | Implementing |
| DND-11 | Edge case: drop outside any panel list | Tasks | Implementing |
| DND-12 | Edge case: marked set emptied mid-drag | Tasks | Implementing |

**Coverage:** 12 total, 0 mapped to tasks, 12 unmapped ⚠️ (expected at Specify stage; Tasks phase maps these)

---

## Success Criteria

- [ ] A file or folder can be copied between the two panels by dragging and dropping, with no keyboard interaction required.
- [ ] No filesystem write ever happens without the user seeing and confirming the destination first.
- [ ] Marked-selection drag behavior matches F5's existing marked/cursor-fallback rule exactly (no behavioral divergence between the two copy entry points).
