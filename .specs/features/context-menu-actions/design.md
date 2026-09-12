# Panel Context Menu Actions Design

**Spec**: `.specs/features/context-menu-actions/spec.md`
**Status**: Draft

---

## Architecture Overview

Four of the six menu items (Abrir, Selecionar/Desselecionar, Editar, Apagar) are thin wiring onto logic `PanelView` already has for F3/F4/F8/Space - no new service surface. The two new items each add exactly one capability behind the existing `FileSystemService` boundary (AD-002): Zipar adds `FileSystemService.zip(_:to:)`, implemented in `MCGuiMacOS` by shelling out to `/usr/bin/zip`; Mostrar Informações adds no protocol surface at all - its one derived value (a folder's recursive size + item count) is computed by walking the already-existing `FileSystemService.listDirectory` from `MCGuiUI`, the same technique `GoToFolderDialogViewModel`'s tree already uses.

```mermaid
graph TD
    A[Right-click a row] --> B[FileRow .contextMenu]
    B --> C1[Abrir -> activate(entry)]
    B --> C2["Selecionar/Desselecionar -> toggleSelection(markedIDs, entry.id)"]
    B --> C3[Editar -> onEditFile(entry)]
    B --> C4["Apagar -> makeDeleteDialog(operationTargets(entry))"]
    B --> C5["Zipar -> beginZip(entry)"]
    B --> C6["Mostrar Informações -> beginInfo(entry)"]
    C5 --> D["FileSystemService.zip(sources, to: destination)"]
    D --> E["/usr/bin/zip via Process (MCGuiMacOS)"]
    C6 --> F[InfoDialogViewModel]
    F -->|folder| G["recursive listDirectory walk (MCGuiUI)"]
```

---

## Code Reuse Analysis

### Existing Components to Leverage

| Component | Location | How to Use |
| --- | --- | --- |
| `activate(_:)` | `Sources/MCGuiUI/Views/PanelView.swift` (existing private func) | Called directly for "Abrir" - identical to double-click/Return, handles both navigate-into-directory and open-in-viewer. |
| `PanelCommands.toggleSelection` | `Sources/MCGuiUI/Commands/PanelCommands.swift:41` | Called directly with the right-clicked entry's id for "Selecionar/Desselecionar" - same function `toggleCurrentSelection()` already calls for Space. |
| `onEditFile` callback | Already threaded into `PanelView` (used by `beginEdit()`) | Called directly with the right-clicked entry for "Editar" - identical to F4. |
| `Self.makeDeleteDialog` | `Sources/MCGuiUI/Views/PanelView.swift` (existing static func, already unit-tested) | Called for "Apagar" with the same marked-set-or-single-row targets F8 already computes via `operationEntries` - generalized to an arbitrary right-clicked row instead of only the cursor row. |
| `CopyMovePlanner.resolvedName` | `Sources/MCGuiCore/Services/CopyMovePlanner.swift:10` | Reused verbatim to pick the zip archive's name without overwriting an existing file. |
| `LoadingOverlay` | `Sources/MCGuiUI/Components/SupportComponents.swift:76` | Reused as the "Zipando…" indeterminate indicator - same component the panel already shows for `viewModel.isLoading`. |
| `FilePermissions` / `PermissionBadge` | `Sources/MCGuiCore/Models/FileEntry.swift`, `Sources/MCGuiUI/Components/SupportComponents.swift` | Reused as-is in the Info dialog's permissions row. |
| `FileSystemServiceError` (`LocalizedError`) | `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift:4` | Extended with one new case for zip failures, following the exact existing pattern (AD-005: typed errors get `LocalizedError` in the target that defines them). |
| Mkdir/Delete dialog pattern (`@Observable` view model + sheet) | `Sources/MCGuiUI/ViewModels/MkdirDialogViewModel.swift`, `Sources/MCGuiUI/Views/MkdirDialog.swift` | Structural template for the new `InfoDialogViewModel`/`InfoDialog` pair - same `@MainActor @Observable` class + plain SwiftUI view + `.sheet` wiring already used four times in this file. |

### Integration Points

| System | Integration Method |
| --- | --- |
| `FileSystemService` protocol (`MCGuiCore`) | Gains one new method: `func zip(_ sources: [FileEntry], to destination: URL) async throws`. |
| `FileSystemServiceImpl` (`MCGuiMacOS`) | Implements `zip` via `Process` at `/usr/bin/zip`, argument array, `currentDirectoryURL` set to the sources' common parent directory. |
| `PanelView` | Replaces the placeholder `.contextMenu { Text(entry.name) }` (`PanelView.swift:175-177`) with the real menu; adds `beginZip(for:)`, `beginInfo(for:)`, `operationTargets(for:)`, and two new `@State` (`isZipping`, `infoViewModel`). |

---

## Components

### `FileSystemService.zip` (protocol addition)

- **Purpose**: Create a single `.zip` archive from one or more source items.
- **Location**: `Sources/MCGuiCore/Protocols/FileSystemService.swift`.
- **Interfaces**: `func zip(_ sources: [FileEntry], to destination: URL) async throws`.
- **Dependencies**: None beyond what the protocol already requires.
- **Reuses**: Same protocol-extension pattern already used for `copy`/`move` progress overloads.

### `FileSystemServiceImpl.zip` (MCGuiMacOS implementation)

- **Purpose**: Invoke `/usr/bin/zip` to produce the archive.
- **Location**: `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift`.
- **Interfaces**: `public func zip(_ sources: [FileEntry], to destination: URL) async throws`.
- **Behavior**: `Process` with `executableURL = URL(fileURLWithPath: "/usr/bin/zip")`, `currentDirectoryURL` = sources' common parent directory, `arguments = ["-r", "-X", "-y", destination.path] + sources.map(\.name)` (relative names, resolved via `currentDirectoryURL` - never absolute paths interpolated into a shell string). Confirmed via `man zip`/`zip -h` on this machine: `zip [-options] zipfile file...` accepts multiple source names in one invocation, `-r` recurses into directories, `-y` stores symlinks as links instead of following them, `-X` excludes extra file attributes (keeps the archive from bundling AppleDouble/resource-fork noise). Non-zero exit status is surfaced as a thrown, typed error with the process's `stderr` text.
- **Dependencies**: `Foundation.Process`.
- **Reuses**: `trash(_:)`'s existing `FailedItem`/`OperationResult`-style error surfacing is the nearest precedent for reporting a filesystem-operation failure in this file, even though `trash` itself uses `FileManager.trashItem` rather than `Process` - this is the first `Process` invocation inside `FileSystemServiceImpl` itself (the codebase's only prior `Process` use, `UserMenuRunner.swift:47-50`, is a different service entirely, invoked via `/bin/sh -c` because User Menu commands are arbitrary user-authored shell snippets - not a precedent to copy here, see Tech Decisions).

### `FileSystemServiceError.zipFailed` (new case)

- **Purpose**: Typed, localized error for a non-zero `zip` exit.
- **Location**: `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift:4` (existing enum).
- **Interfaces**: `case zipFailed(reason: String)`, `LocalizedError.errorDescription` per the existing per-case pattern.
- **Reuses**: Existing `FileSystemServiceError`/`LocalizedError` conformance already on this enum (AD-005).

### `PanelView.operationTargets(for:)` (new helper)

- **Purpose**: Generalizes the existing `operationEntries` (cursor-row-only) rule to an arbitrary right-clicked row: marked set if that row is marked, else just that row.
- **Location**: `Sources/MCGuiUI/Views/PanelView.swift`, next to `operationEntries`.
- **Interfaces**: `private func operationTargets(for entry: FileEntry) -> [FileEntry]` - `markedIDs.contains(entry.id) ? markedEntries : [entry]`.
- **Reuses**: `markedIDs`, `markedEntries` (existing).

### `PanelView.beginZip(for:)` (new)

- **Purpose**: Wires "Zipar" to `FileSystemService.zip`, computing the destination name/path per the spec's naming rule.
- **Location**: `Sources/MCGuiUI/Views/PanelView.swift`.
- **Interfaces**: `private func beginZip(for entry: FileEntry) { ... }` (starts a guarded `Task`, sets `isZipping`, computes destination via `CopyMovePlanner.resolvedName`, calls `fileSystemService.zip`, reloads the panel on success, surfaces `operationErrorMessage` on failure).
- **Dependencies**: `fileSystemService.zip`, `CopyMovePlanner.resolvedName`, `viewModel.load()`.
- **Reuses**: The existing `operationErrorMessage` display mechanism (`displayedErrorMessage`) already shown via `ErrorAlert` in the panel's `ZStack`.

### `InfoDialogViewModel` (new)

- **Purpose**: Holds the static `FileEntry` fields plus the async recursive size/item-count for folders.
- **Location**: `Sources/MCGuiUI/ViewModels/InfoDialogViewModel.swift`.
- **Interfaces**:
  - `init(entry: FileEntry, fileSystemService: FileSystemService)`
  - `public private(set) var totalSize: Int64?` (`nil` while calculating, for a folder)
  - `public private(set) var itemCount: Int?`
  - `func startSizeCalculationIfNeeded() async` - only runs for `entry.type == .directory`; recurses via `fileSystemService.listDirectory`, accumulating `size` and count; supports `Task` cancellation (stops accumulating, leaves fields as last-known-partial or nil, per Edge Cases: cancelled on dialog close).
- **Dependencies**: `FileSystemService.listDirectory`.
- **Reuses**: Same recursive-listing technique as `DirectoryTreeNodeViewModel.loadChildrenIfNeeded` (`Sources/MCGuiUI/ViewModels/DirectoryTreeNodeViewModel.swift`), generalized from "one level, directories only" to "every level, files and directories, accumulating size."

### `InfoDialog` (new view)

- **Purpose**: Displays `InfoDialogViewModel`'s fields; shows "Calculando…" for `totalSize == nil` on a folder.
- **Location**: `Sources/MCGuiUI/Views/InfoDialog.swift`.
- **Interfaces**: `InfoDialog(viewModel: InfoDialogViewModel, onClose: () -> Void)`.
- **Reuses**: `PermissionBadge`, `ByteCountFormatter` usage pattern already established in `FileRow`/`ProgressDialog`; `.task { await viewModel.startSizeCalculationIfNeeded() }` for cancellation-on-dismiss, the same idiom `GoToFolderDialog`'s tree-expansion `.task` already uses.

---

## Data Models

### `InfoDialogViewModel` state (not `Codable`, in-memory only)

```swift
let entry: FileEntry          // existing model, unchanged
var totalSize: Int64?         // nil until computed (files: set immediately from entry.size)
var itemCount: Int?           // nil for files; folders: files + subfolders contained
```

**Relationships**: Wraps one existing `FileEntry`; adds no persistence and no new `Codable` model.

---

## Error Handling Strategy

| Error Scenario | Handling | User Impact |
| --- | --- | --- |
| `zip` process exits non-zero (permission denied, disk full, etc.) | `FileSystemServiceError.zipFailed(reason:)` thrown, caught in `beginZip`, no partial file left (zip is written to a temp name and only moved into place on success - see Risks) | `operationErrorMessage` shows the reason via the existing `ErrorAlert` overlay. |
| Folder size calculation hits a permission-denied subdirectory mid-walk | That subtree is skipped (size/count continue from what's readable), matching `DirectoryTreeNodeViewModel`'s existing `(try? await ...) ?? []` swallow-and-continue pattern | The total may under-count silently; acceptable since this mirrors the tree dialog's existing behavior rather than introducing a new failure mode. |
| Dialog closed before size calculation finishes | The backing `Task` is cancelled (SwiftUI `.task` modifier cancels automatically on view disappearance) | No orphaned background work continues after the dialog closes. |

---

## Risks & Concerns

| Concern | Location (file:line) | Impact | Mitigation |
| --- | --- | --- | --- |
| `zip` writing directly to the final destination name could leave a corrupt/partial archive if the process is killed or fails mid-write | New `FileSystemServiceImpl.zip` | A half-written `.zip` could appear in the listing and confuse the user | Have `zip` write to a temporary name in the same directory (e.g. `.<name>.zip.partial`) and `FileManager.moveItem` it to the final resolved name only after the process exits 0; on failure, delete the temp file. |
| Recursive folder-size walk has no depth/file-count cap | New `InfoDialogViewModel.startSizeCalculationIfNeeded` | A pathologically deep or huge tree (e.g. `node_modules`, a mounted network volume) could make the calculation run for a long time | Acceptable per spec (P3 is explicitly lower priority, no cancel button requested beyond dialog-close cancellation); `Task` cancellation on dialog close already bounds the worst case to "however long the user leaves the dialog open." No hard cap added, since the spec did not ask for one and inventing a silent truncation would make the shown total quietly wrong. |
| `PanelView.swift` is already large (many `@State`, many `begin*` functions) | `Sources/MCGuiUI/Views/PanelView.swift` (pre-existing, growing with every panel feature) | Continuing to add state/functions to one file increases the risk of merge conflicts and makes the file harder to scan | Out of scope for this feature to refactor; noted so a future dedicated refactor (splitting `PanelView`'s action-building functions into a separate file/extension) can be considered - no behavior change needed today. |

---

## Tech Decisions (only non-obvious ones)

| Decision | Choice | Rationale |
| --- | --- | --- |
| Zip tool | `/usr/bin/zip` (Info-ZIP, ships with macOS) via `Process`, not `ditto` | `man ditto`'s archive-creation form (`ditto -c -k src dst_archive`) only accepts a single `src`; zipping a multi-item marked set would need a staging directory. `zip -r zipfile file1 file2 ...` accepts multiple sources natively in one invocation - confirmed via `zip -h` on this machine - so one tool covers both the single-item and marked-set cases without extra staging I/O. |
| `Process` invocation shape | Argument array (`arguments: [String]`) directly against `/usr/bin/zip`, never `/bin/sh -c` with an interpolated string | The codebase's only existing `Process` use (`UserMenuRunner.swift:47-50`) goes through `/bin/sh -c` because it must run arbitrary user-authored shell commands, and was hardened by shell-*escaping* the interpolated value (`ee5e610`) rather than avoiding the shell - that escaping was necessary there but is a weaker posture than not using a shell at all. Zip's arguments are fully known ahead of time (a fixed set of flags plus file names), so this call site can skip the shell entirely and pass arguments directly - structurally immune to shell-injection regardless of characters in file names, a stricter bar than the existing precedent. |
| Where folder-size calculation lives | `MCGuiUI` (recursing over the existing `FileSystemService.listDirectory`), not a new `FileSystemService` method | The capability ("sum sizes recursively") is already fully expressible with the existing protocol; adding an OS-specific method for something with no OS-specific need would violate AD-002's "OS-specific work belongs in `MCGuiMacOS`" without buying anything - recursion is plain, portable logic. |

> **Project-level decision recorded**: This design's argument-array-only `Process` rule is now `AD-006` in `.specs/STATE.md` (see below) - it's a constraint any future feature that shells out to a CLI tool must follow, not just this one.
