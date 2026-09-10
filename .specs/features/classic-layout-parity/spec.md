# Classic Layout Parity Specification

## Problem Statement

The Swift/SwiftUI rewrite (`convert-to-swift-swiftui`) reproduces the original terminal Midnight Commander's *behavior* but not its *layout*: it has no in-window top menu bar, no bottom function-key button bar, and an extra volumes sidebar the terminal app never had. The user rejected the current layout and wants the window structure to visually match the original ncurses app (`/Users/pacelli/git/pacelli/mc`): two file panels, a top menu row, and a row of numbered buttons at the bottom.

## Goals

- [ ] In-window top bar with the original's five menu entries (Left, File, Command, Options, Right), in addition to the existing native macOS menu bar.
- [ ] Bottom button bar with the original's 10 numbered F-key buttons and labels, spanning the window width.
- [ ] Each panel shows a header (current path) and footer (entry/selection summary), matching the original panel's title/status-line chrome.
- [ ] Volumes sidebar removed; volume navigation moves into the Left/Right menus (matching the original, which has no persistent sidebar).

## Out of Scope

| Feature | Reason |
| --- | --- |
| Exact ncurses color scheme (blue/cyan background, reverse-video selection) | User asked for layout parity, not skin/theme parity; native macOS control styling is used instead |
| ASCII box-drawing borders | Native macOS apps don't render box-drawing glyphs as window chrome; a plain header/footer bar conveys the same structure |
| F1 Help content, F2 User-menu content | No help/user-menu system exists yet (pre-existing, out of this feature) |
| F9 PullDn actually opening a menu programmatically | SwiftUI's `Menu` has no public API to open from code; button stays present but disabled |
| Left/Right menu's full original command set (listing mode, tree, compare, encoding, filter) | Only volume navigation + refresh are needed to replace the removed sidebar; the rest is future scope |

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Keep native macOS menu bar or replace with in-window bar | Both: native bar stays, in-window Left/File/Command/Options/Right bar is added | User explicitly chose "as duas" when asked | y |
| Volumes sidebar | Removed | User explicitly confirmed removal to match the original's layout | y |
| Visual styling of the new bars | Native SwiftUI control styling (system colors/fonts), not literal terminal blue/cyan | User's request was about layout/structure, not the ncurses color skin; kept as an explicit assumption since not directly asked | n |
| F1/F2/F9 button bar buttons with no backing implementation | Rendered present but disabled, each with an inline `SPEC_DEVIATION` comment | Matches the project's existing convention for documented, accepted gaps (see STATE.md Known Limitations) rather than silently doing nothing | n |

**Open questions:** none - all resolved or logged above.

---

## User Stories

### P1: In-Window Top Bar ⭐ MVP

**User Story**: As a user of the original terminal mc, I want the same Left/File/Command/Options/Right menu row at the top of the window, so the app feels like the same tool.

**Why P1**: This is the single most visible structural element the user called out as missing.

**Acceptance Criteria**:

1. The system SHALL render an in-window bar above the two panels with five menu entries, in order: Left, File, Command, Options, Right.
2. WHEN the user opens the Left menu THEN the system SHALL list currently mounted volumes and, on selection, SHALL navigate the left panel (regardless of which panel is active) to that volume's root.
3. WHEN the user opens the Right menu THEN the system SHALL do the same for the right panel.
4. The native macOS menu bar (App/File/Edit/View/Go/Window/Help) SHALL remain unchanged and continue to function alongside the new in-window top bar.

### P1: Bottom Button Bar ⭐ MVP

**User Story**: As a user of the original terminal mc, I want the same numbered F-key button row at the bottom of the window, so the available actions are visible without opening a menu.

**Why P1**: The second structural element the user called out as missing.

**Acceptance Criteria**:

1. The system SHALL render a button bar docked to the bottom of the window, spanning its full width.
2. WHILE the button bar is shown, each of its 10 buttons SHALL display its function-key number followed by its classic label: 1 Help, 2 Menu, 3 View, 4 Edit, 5 Copy, 6 RenMov, 7 Mkdir, 8 Delete, 9 PullDn, 10 Quit.
3. WHEN the user clicks button 3, 4, 5, 6, 7, or 8 THEN the system SHALL invoke the same action as pressing the matching physical F-key (F3-F8) on the currently active panel.
4. WHEN the user clicks button 10 (Quit) THEN the system SHALL terminate the app.
5. IF a button has no backing implementation (buttons 1, 2, 9) THEN the system SHALL render it disabled rather than performing no visible action on click.

### P1: Panel Header/Footer Chrome ⭐ MVP

**User Story**: As a user, I want each panel to show its current path and a summary line, so I can see where I am and what's selected, like the original panel's title/status line.

**Why P1**: Without this, the panels read as plain lists rather than the original's bordered, titled panes.

**Acceptance Criteria**:

1. WHILE a panel is shown, its header SHALL display the panel's current directory path.
2. WHILE a panel is shown, its footer SHALL display the total entry count.
3. WHEN one or more entries are selected THEN the footer SHALL display the selected count in place of (or alongside) the total.

### P1: Remove Volumes Sidebar ⭐ MVP

**User Story**: As a user comparing this app to the original, I want no extra sidebar the original doesn't have, so the two-panel layout matches exactly.

**Why P1**: The sidebar is the clearest structural deviation from the original beyond the missing bars above.

**Acceptance Criteria**:

1. The system SHALL NOT render a persistent volumes sidebar in the main window.
2. The system SHALL make volume navigation reachable via the Left/Right menus (Top Bar story) instead.

---

## Edge Cases

| # | Edge case | Handling |
| --- | --- | --- |
| 1 | Active panel has no selection when button 3/4/5/6/7/8 is clicked | Same no-op behavior as the existing physical F-key handling (PanelView's existing `targetEntry`/dialog-builder logic already returns `nil`/no dialog for empty selection) |
| 2 | No volumes mounted when Left/Right menu opens | Menu entry list is empty; menu itself stays present but shows nothing to pick (mirrors the removed sidebar's existing empty-state behavior) |
| 3 | Window narrower than all 10 button labels fit | Buttons compress via `.frame(maxWidth: .infinity)` equal-width distribution rather than overflowing off-window |

---

## Requirement Traceability

| Requirement | User Story | Phase | Status |
| --- | --- | --- | --- |
| CL-01 | P1: In-Window Top Bar | Execute | Verified |
| CL-02 | P1: In-Window Top Bar | Execute | Verified |
| CL-03 | P1: In-Window Top Bar | Execute | Verified |
| CL-04 | P1: In-Window Top Bar | Execute | Verified |
| CL-05 | P1: Bottom Button Bar | Execute | Verified |
| CL-06 | P1: Bottom Button Bar | Execute | Verified |
| CL-07 | P1: Bottom Button Bar | Execute | Verified |
| CL-08 | P1: Bottom Button Bar | Execute | Verified |
| CL-09 | P1: Bottom Button Bar | Execute | Verified |
| CL-10 | P1: Panel Header/Footer Chrome | Execute | Verified |
| CL-11 | P1: Panel Header/Footer Chrome | Execute | Verified |
| CL-12 | P1: Panel Header/Footer Chrome | Execute | Verified |
| CL-13 | P1: Remove Volumes Sidebar | Execute | Verified |
| CL-14 | P1: Remove Volumes Sidebar | Execute | Verified |

---

## Success Criteria

- `swift build && swift test` passes with no regressions in the existing 225 tests.
- `swift run MCGuiApp` shows: native macOS menu bar (unchanged) + new in-window Left/File/Command/Options/Right bar + two panels with header/footer chrome + bottom 10-button bar; no volumes sidebar.
- User visually confirms the layout matches the original terminal app's structure.
