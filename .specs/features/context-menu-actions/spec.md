# Panel Context Menu Actions Specification

## Problem Statement

Right-clicking a row in either panel today shows a placeholder context menu with nothing but the file name (`PanelView.swift`'s `entryList`, `.contextMenu { Text(entry.name) }`). Every action a user might reach for from a right-click - opening, marking, editing, deleting, compressing, inspecting - already exists behind function keys, except compressing and inspecting, which don't exist yet at all.

## Goals

- [ ] Right-clicking any row offers Abrir, Selecionar/Desselecionar, Zipar, Editar, Apagar, and Mostrar Informações.
- [ ] Abrir, Selecionar/Desselecionar, Editar, and Apagar reuse the panel's existing F3/F4/F8/toggle logic exactly - no parallel implementation.
- [ ] Zipar and Mostrar Informações are net-new capabilities added behind the existing `FileSystemService` boundary (`MCGuiCore` protocol, `MCGuiMacOS` implementation), per AD-002.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Unzip / extract archives | Not requested; only compressing (Zipar) is in scope. |
| Renaming from the context menu | Not requested; no existing rename flow to reuse either (would be new scope). |
| Multi-format archives (tar, 7z, rar) | Not requested; Zipar produces `.zip` only. |
| Cancelling an in-flight Zip | Not requested; MVP zip is not cancellable (see Edge Cases). |
| Aggregate "Info" for multiple marked items at once | Not requested; Mostrar Informações always targets the single right-clicked item, matching macOS's own Get Info. |
| Live-updating the Info dialog if the file changes on disk while it's open | Not requested; the dialog reads state once (plus the async folder-size calculation) and does not watch the filesystem afterward. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Zip scope when the right-clicked row is part of the marked set | Same rule as F5/F8: zip the whole marked set into one `.zip`; otherwise zip only the right-clicked row | User confirmed matching existing `operationEntries` semantics | y |
| Apagar (Delete) scope from the context menu | Same `operationEntries` rule applied consistently: marked set if the row is marked, otherwise just that row | Not asked separately, but Delete already uses this exact rule via F8 today (`PanelView.operationEntries`); special-casing the context menu to behave differently would contradict the "reuse existing logic" goal | n (derived from existing F8 behavior, logged as default) |
| Abrir / Editar scope | Always the single right-clicked row, regardless of marks | Matches F3/F4's existing cursor-only semantics (view/edit always act on one file, never a batch) | n (derived from existing F3/F4 behavior, logged as default) |
| Mostrar Informações scope | Always the single right-clicked row, regardless of marks | Matches how macOS's own Get Info works (per-item); an aggregate multi-item info view was never requested | n (undiscussed, logged as default) |
| Folder size calculation | Computed in `MCGuiUI` by recursively calling the existing `FileSystemService.listDirectory`, no new protocol method needed; shown as "Calculando…" until it resolves | User confirmed recursive calculation is wanted; reusing `listDirectory` avoids adding OS-specific surface for something already expressible with the existing protocol | y (background calc) / n (mechanism, logged as default) |
| Info dialog fields | Name, full path, kind (file/folder/symlink + target if symlink), size (recursive + item count for folders), permissions (reusing the existing `FilePermissions`/`PermissionBadge`), created date, modified date | Not asked field-by-field; matches the data `FileEntry` already carries plus the one new derived value (folder size/count) | n (undiscussed, logged as default) |
| Zip output location and naming | Same directory as the source item(s); single item → `<name>.zip` (e.g. `notes.txt` → `notes.txt.zip`, `Photos/` → `Photos.zip`); multiple marked items → `Archive.zip`. Name conflicts resolved via the existing `CopyMovePlanner.resolvedName` (never overwrites) | Matches macOS Finder's own "Compress" naming convention for the single-item case; reuses the already-tested conflict-naming helper instead of a new one | n (undiscussed, logged as default) |
| Zip mechanism | A new `FileSystemService.zip(_:to:)` method, implemented in `MCGuiMacOS` by invoking an OS zip tool as a subprocess via `Process` with an argument array (never an interpolated shell string) | Keeps the OS-specific call behind the existing AD-002 boundary; argument-array `Process` invocation avoids the shell-injection class of bug this repo already fixed once for User Menu macros (`ee5e610`); exact tool/flags are a Design-time decision | n/a - implementation detail, security constraint is binding |
| Zip progress feedback | Indeterminate "Zipping…" spinner, not byte-level progress | The underlying tool does not expose granular per-file progress the way the existing copy engine does; an indeterminate spinner is sufficient given zip is not in the critical/frequent path | n (undiscussed, logged as default) |
| Right-click target vs. keyboard cursor | Right-clicking a row makes that row the action target for this menu invocation; whether the visible keyboard cursor also moves there is an implementation detail resolved at Design time by how SwiftUI's `List` selection binding behaves on secondary click | Avoids asserting untested SwiftUI behavior in the spec; the user-visible contract (the menu acts on the row you right-clicked) is what matters and is fully specified | n/a - implementation detail |

**Open questions:** none - all resolved above (confirmed by user or logged as a reasoned default).

---

## User Stories

### P1: Reuse existing actions from the context menu ⭐ MVP

**User Story**: As a user, I want to right-click a file or folder and choose Abrir, Selecionar/Desselecionar, Editar, or Apagar, so that I don't have to remember function-key shortcuts for actions I already have.

**Why P1**: Zero new capability - purely wiring the menu to logic that already exists and is already tested (F3/F4/F8, `toggleSelection`). Delivers immediate value with the least risk.

**Acceptance Criteria**:

1. WHEN the user right-clicks a row THEN the system SHALL show a context menu with items: Abrir, Selecionar or Desselecionar (whichever applies), Zipar, Editar, Apagar, Mostrar Informações.
2. WHEN the user chooses Abrir on a directory row THEN the system SHALL navigate into that directory, identical to double-clicking or pressing Return on it.
3. WHEN the user chooses Abrir on a file row THEN the system SHALL open it in the viewer, identical to double-clicking or pressing Return on it.
4. WHEN the right-clicked row is not currently marked THEN the menu item SHALL read "Selecionar", and choosing it SHALL mark that row, identical to pressing Space on it.
5. WHEN the right-clicked row is currently marked THEN the menu item SHALL read "Desselecionar", and choosing it SHALL unmark that row, identical to pressing Space on it.
6. WHEN the user chooses Editar THEN the system SHALL open that row's file in the editor, identical to pressing F4 with the cursor on it.
7. WHEN the user chooses Apagar THEN the system SHALL open the existing delete confirmation dialog (`DeleteConfirmDialog`) targeting the marked set if the row is marked, or just that row otherwise - identical to pressing F8.

**Independent Test**: Right-click an unmarked file, choose Selecionar, see it marked; right-click it again, choose Desselecionar (label changed), see it unmarked. Right-click a folder, choose Abrir, see the panel navigate into it. Right-click a file, choose Editar, see the editor open. Right-click a file, choose Apagar, see the same delete dialog F8 produces.

---

### P2: Compress to a zip archive

**User Story**: As a user, I want to right-click a file or folder (or a marked set) and choose Zipar, so that I can create a `.zip` without leaving the app.

**Why P2**: New capability, but a single well-scoped action with a clear, common use case.

**Acceptance Criteria**:

1. WHEN the user chooses Zipar on a row that is not marked THEN the system SHALL create a single `.zip` archive containing only that row's file or folder, in the same directory as the source.
2. WHEN the user chooses Zipar on a row that is part of the current marked set THEN the system SHALL create a single `.zip` archive containing every marked item, in the same directory as the (single) source(s) - see Edge Cases for marked items spanning conceptually different locations.
3. WHEN the resulting archive's name would collide with an existing file in that directory THEN the system SHALL pick the next available name via the existing numeric-suffix rule (`CopyMovePlanner.resolvedName`) rather than overwriting anything.
4. WHILE the zip is being created THE system SHALL show an indeterminate "Zipping…" indicator.
5. WHEN zip creation finishes successfully THEN the system SHALL refresh the panel so the new archive appears in the listing.
6. IF zip creation fails (e.g., permission denied, disk full) THEN the system SHALL show an error message and SHALL NOT leave a partial/corrupt archive behind.

**Independent Test**: Right-click an unmarked folder, choose Zipar, see `<FolderName>.zip` appear next to it after the spinner clears; mark 2 files, right-click one of them, choose Zipar, see one `Archive.zip` containing both.

---

### P3: Show file/folder information

**User Story**: As a user, I want to right-click a file or folder and choose Mostrar Informações, so that I can see its size, dates, permissions, and path without leaving the panel.

**Why P3**: New capability, read-only and lower urgency than compressing, but still explicitly requested.

**Acceptance Criteria**:

1. WHEN the user chooses Mostrar Informações on a file row THEN the system SHALL show a dialog with: name, full path, kind, size, permissions, created date, modified date.
2. WHEN the user chooses Mostrar Informações on a folder row THEN the system SHALL show the same fields, with size initially labeled "Calculando…" and permissions/dates/path/kind available immediately.
3. WHEN the folder's recursive size finishes computing THEN the system SHALL update the dialog in place with the total size and the item count (files + subfolders contained).
4. WHEN the user chooses Mostrar Informações on a symlink row THEN the system SHALL additionally show the link's target path.
5. WHEN the user closes the dialog before the folder-size calculation finishes THEN the system SHALL cancel that calculation rather than let it keep running in the background.

**Independent Test**: Right-click a file, choose Mostrar Informações, see its size/dates/permissions immediately. Right-click a large folder, choose Mostrar Informações, see "Calculando…" replaced by a real total after a moment.

---

## Edge Cases

- IF the user right-clicks empty panel space (no row under the cursor) THEN the system SHALL NOT show this per-row context menu (existing placeholder scoped to `FileRow`, unaffected).
- IF Zipar is invoked on a marked set THEN the system SHALL only need one destination directory to place the archive in, since marked items always come from the same panel/directory listing; this feature does not support marking items across two different directories in the same panel (not possible with the current single-directory listing model).
- IF Apagar is invoked from the context menu while a copy/move operation is already running (`operationTask != nil`) THEN the system SHALL follow the same existing guard `beginDelete` already has today (no new behavior).
- IF Zipar is invoked while a copy/move/zip operation is already running on that panel THEN the system SHALL ignore the new Zipar request until the current one finishes, mirroring the existing single-in-flight-operation rule.
- WHEN a folder is empty THEN its Mostrar Informações size SHALL resolve to 0 bytes / 0 items rather than staying on "Calculando…" indefinitely.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| CTXM-01 | P1: Reuse existing actions | Verified | ⏭️ UAT-required (code-verified) |
| CTXM-02 | P1: Reuse existing actions | Verified | ⏭️ UAT-required (code-verified) |
| CTXM-03 | P1: Reuse existing actions | Verified | ⏭️ UAT-required (code-verified) |
| CTXM-04 | P1: Reuse existing actions | Verified | ⏭️ UAT-required (code-verified) |
| CTXM-05 | P1: Reuse existing actions | Verified | ⏭️ UAT-required (code-verified) |
| CTXM-06 | P1: Reuse existing actions | Verified | ⏭️ UAT-required (code-verified) |
| CTXM-07 | P1: Reuse existing actions | Verified | ✅ Verified |
| CTXM-08 | P2: Zip | Verified | ✅ Verified |
| CTXM-09 | P2: Zip | Verified | ✅ Verified |
| CTXM-10 | P2: Zip | Verified | ✅ Verified |
| CTXM-11 | P2: Zip | Verified | ✅ Verified |
| CTXM-12 | P2: Zip | Verified | ⏭️ UAT-required (code-verified) |
| CTXM-13 | P2: Zip | Verified | ⏭️ UAT-required (code-verified) |
| CTXM-14 | P3: Show info | Verified | ✅ Verified (view-model layer) |
| CTXM-15 | P3: Show info | Verified | ✅ Verified (view-model layer) |
| CTXM-16 | P3: Show info | Verified | ✅ Verified |
| CTXM-17 | P3: Show info | Verified | ⚠️ Coverage gap - not blocking, see validation.md Recommendation |
| CTXM-18 | P3: Show info | Verified | ✅ Verified (cancellation logic) |
| CTXM-19 | Edge case: no row under cursor | Verified | ✅ Verified (structural) |
| CTXM-20 | Edge case: operation already running (delete) | Verified | ✅ Verified |
| CTXM-21 | Edge case: operation already running (zip) | Verified | ✅ Verified |
| CTXM-22 | Edge case: empty folder info | Verified | ✅ Verified |

**Coverage:** 22 total, 22 mapped to tasks (T1-T10), 0 unmapped. Verifier PASS - see `.specs/features/context-menu-actions/validation.md` for full evidence (10/22 directly test-covered, 11/22 flagged UAT-required for GUI-only behavior, 1/22 minor non-blocking coverage gap).

---

## Success Criteria

- [ ] Every action available today via F3/F4/F8/Space is also reachable from the right-click menu with identical behavior (no divergent code paths).
- [ ] Zipar produces a valid `.zip` that unzips correctly and never overwrites an existing file.
- [ ] Mostrar Informações never blocks the UI while computing a folder's size - the dialog opens immediately with "Calculando…".
