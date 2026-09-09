# Convert to Swift and SwiftUI Specification

## Problem Statement

The current project is a dual-pane file manager built with C#/.NET and Avalonia UI, targeting macOS. We need to rewrite it as a native macOS application using Swift and SwiftUI to achieve better performance, native integration, reduced dependencies, and improved maintainability. The rewrite must preserve all existing functionality while leveraging SwiftUI's declarative UI paradigm and macOS-native APIs.

## Goals

- [ ] Full feature parity with existing C# implementation
- [ ] Native macOS application using Swift 5.9+ and SwiftUI
- [ ] Swift Package Manager for dependency management
- [ ] Unit tests with Swift Testing framework
- [ ] UI tests with XCUITest
- [ ] Zero external UI framework dependencies (no Avalonia, no AppKit bridging)
- [ ] Performance equal to or better than current implementation

## Out of Scope

| Feature | Reason |
|---------|--------|
| Windows/Linux support | Current project is macOS-only; cross-platform not required |
| Avalonia migration path | Complete rewrite, not incremental migration |
| Cloud sync / network drives | Not in current implementation |
| Plugin system | Not in current implementation |
| Custom themes beyond light/dark | Current only supports light/dark |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|----------------------|----------------|-----------|------------|
| Project structure | Swift Package Manager with single package | Simplest native approach; no Xcode project file maintenance | y |
| Minimum macOS version | macOS 14.0 (Sonoma) | SwiftUI maturity; supports modern APIs | y |
| Swift version | Swift 5.9+ | Required for SwiftUI features and macros | y |
| File system API | FileManager + NSFileProvider | Native, well-tested, supports async/await | y |
| Trash implementation | NSFileManager.trashItem | Native trash integration | y |
| Text editor component | NSTextView wrapped in SwiftUI | Full-featured editor; Syntax highlighting via TextKit 2 | y |
| Image viewer | NSImage + SwiftUI | Native image support | y |
| Hex viewer | Custom SwiftUI view | No native hex view; build custom | y |
| Keyboard shortcuts | SwiftUI `.keyboardShortcut` + `Commands` | Declarative, integrates with menu bar | y |
| Path history persistence | JSON file in Application Support | Simple, no database dependency | y |
| Testing framework | Swift Testing (unit) + XCUITest (UI) | Modern, Swift-native, Apple-supported | y |
| Build system | `swift build` / `xcodebuild` | Standard SPM workflow | y |
| Code organization | Feature-based modules | Matches current Clean Architecture layers | y |

**Open questions:** none - all resolved or logged above.

---

## User Stories

### P1: Project Foundation ⭐ MVP

**User Story**: As a developer, I want a Swift Package Manager project structure with core domain models so that I can build the application on a solid foundation.

**Why P1**: Without the project structure and domain models, no other features can be implemented.

**Acceptance Criteria** (each line is one EARS pattern):

1. The system SHALL compile with `swift build` on macOS 14+ with Swift 5.9+
2. The system SHALL define all domain models (FileEntry, PanelState, OperationMode, OperationProgress, OperationResult, CopyMoveOptions, CopyMovePlan, EditorDocumentState, ViewerState, ViewerContent, PanelPathHistory, PanelSortColumn, FileConflictResolution) as Swift structs/enums
3. The system SHALL define all service protocols (FileSystemService, EditorService, ViewerService, TrashService, PathHistoryStore) as Swift protocols
4. The system SHALL include Swift Testing configuration with at least one passing test
5. WHEN the package is built THEN it SHALL produce a macOS executable target

**Independent Test**: Run `swift build` and `swift test` - both succeed.

---

### P1: File System Service (macOS) ⭐ MVP

**User Story**: As a user, I want to browse the file system in two panels so that I can navigate and manage files.

**Why P1**: Core file browsing is the primary purpose of the application.

**Acceptance Criteria**:

1. WHEN the app launches THEN the system SHALL display two file panels side by side
2. WHEN a panel receives focus THEN the system SHALL highlight the active panel
3. WHEN the user navigates to a directory THEN the system SHALL list files and directories with name, size, modification date, and permissions
4. WHEN the user presses Enter on a directory THEN the system SHALL navigate into that directory
5. WHEN the user presses Backspace THEN the system SHALL navigate to the parent directory
6. WHEN the user presses Cmd+Up THEN the system SHALL navigate to the parent directory
7. WHILE a directory is loading THEN the system SHALL show a loading indicator
8. IF a directory cannot be read THEN the system SHALL display an error alert with the reason
9. The system SHALL support sorting by name, size, date, and type (ascending/descending)
10. The system SHALL support filtering hidden files toggle
11. The system SHALL persist panel path history per panel (back/forward navigation)
12. WHEN the user presses Cmd+[ THEN the system SHALL go back in history
13. WHEN the user presses Cmd+] THEN the system SHALL go forward in history

**Independent Test**: Launch app, navigate directories in both panels, verify back/forward, sorting, hidden files toggle.

---

### P1: File Operations (Copy, Move, Delete, New Folder) ⭐ MVP

**User Story**: As a user, I want to copy, move, delete, and create folders so that I can manage my files.

**Why P1**: File manipulation is the core value proposition of a file manager.

**Acceptance Criteria**:

1. WHEN the user selects files and presses F5 (copy) THEN the system SHALL show a copy/move dialog with source, destination, and options
2. WHEN the user selects files and presses F6 (move) THEN the system SHALL show a copy/move dialog with move mode
3. WHEN the user confirms a copy operation THEN the system SHALL copy files preserving metadata (timestamps, permissions)
4. WHEN the user confirms a move operation THEN the system SHALL move files (rename within volume, copy+delete across volumes)
5. IF a destination file exists THEN the system SHALL show a conflict dialog with options: Overwrite, Skip, Rename, Cancel
6. WHEN the user selects Overwrite THEN the system SHALL replace the destination file
7. WHEN the user selects Skip THEN the system SHALL continue with next file
8. WHEN the user selects Rename THEN the system SHALL auto-rename with numeric suffix (file (1).txt)
9. WHEN the user selects Cancel THEN the system SHALL abort the entire operation
10. WHEN the user presses F7 THEN the system SHALL show a new folder dialog
11. WHEN the user enters a name and confirms THEN the system SHALL create the directory
12. WHEN the user presses F8 (delete) THEN the system SHALL show a delete confirmation dialog
13. WHEN the user confirms deletion THEN the system SHALL move files to Trash (not permanent delete)
14. WHILE an operation is in progress THEN the system SHALL show a progress dialog with current file, bytes transferred, speed, ETA
15. IF an operation fails THEN the system SHALL show an error with the specific file and reason
16. The system SHALL support canceling an in-progress operation

**Independent Test**: Perform copy, move, delete, mkdir operations with various conflict scenarios; verify Trash integration.

---

### P1: File Viewer ⭐ MVP

**User Story**: As a user, I want to view file contents (text, images, hex) so that I can inspect files without opening external apps.

**Why P1**: Built-in viewer is a key differentiator for a file manager.

**Acceptance Criteria**:

1. WHEN the user presses F3 on a file THEN the system SHALL open the viewer window
2. WHEN viewing a text file THEN the system SHALL display syntax-highlighted content with line numbers
3. WHEN viewing an image file THEN the system SHALL display the image with zoom/pan support
4. WHEN viewing a binary file THEN the system SHALL display hex dump with ASCII representation
5. WHEN the viewer is open THEN the system SHALL support navigation to next/previous file in panel (Tab / Shift+Tab)
6. WHEN the viewer is open THEN the system SHALL support search within text files (Cmd+F)
7. The system SHALL handle files up to 100MB without freezing the UI
8. IF a file cannot be read THEN the system SHALL show an error in the viewer

**Independent Test**: Open various file types in viewer; verify navigation, search, large file handling.

---

### P1: Text Editor ⭐ MVP

**User Story**: As a user, I want to edit text files so that I can modify files directly in the file manager.

**Why P1**: Built-in editor completes the file management workflow.

**Acceptance Criteria**:

1. WHEN the user presses F4 on a text file THEN the system SHALL open the editor window
2. WHEN the editor opens THEN the system SHALL load file content with syntax highlighting
3. WHEN the user edits content THEN the system SHALL track unsaved changes
4. WHEN the user presses Cmd+S THEN the system SHALL save the file
5. WHEN the user attempts to close with unsaved changes THEN the system SHALL prompt: Save, Don't Save, Cancel
6. WHEN the user selects Save THEN the system SHALL write changes and clear dirty flag
7. WHEN the user selects Don't Save THEN the system SHALL discard changes and close
8. WHEN the user selects Cancel THEN the system SHALL keep the editor open
9. The system SHALL support basic editing: cut, copy, paste, undo, redo, select all
10. The system SHALL support find/replace (Cmd+F / Cmd+Option+F)

**Independent Test**: Open, edit, save, cancel text files; verify syntax highlighting, dirty tracking, find/replace.

---

### P1: Keyboard Navigation & Shortcuts ⭐ MVP

**User Story**: As a power user, I want full keyboard control so that I can work efficiently without a mouse.

**Why P1**: Dual-pane file managers are keyboard-centric tools.

**Acceptance Criteria**:

1. The system SHALL support Tab to switch focus between panels
2. The system SHALL support arrow keys for selection navigation
3. The system SHALL support Shift+Arrow for range selection
4. The system SHALL support Cmd+Arrow for jump to first/last
5. The system SHALL support Space to toggle selection
6. The system SHALL support Insert to toggle selection and move down
7. The system SHALL support F3 (view), F4 (edit), F5 (copy), F6 (move), F7 (mkdir), F8 (delete)
8. The system SHALL support Cmd+1/2/3/4 for sort by name/size/date/type
9. The system SHALL support Cmd+. for toggle hidden files
10. The system SHALL support Cmd+Up (parent), Cmd+[ (back), Cmd+] (forward)
11. The system SHALL support Enter (enter directory / open file)
12. The system SHALL support Escape to close dialogs / clear selection

**Independent Test**: Perform all file operations using only keyboard; verify all shortcuts work.

---

### P1: Theme Support (Light/Dark) ⭐ MVP

**User Story**: As a user, I want the app to respect system theme and allow manual override so that it matches my preference.

**Why P1**: Basic accessibility and user expectation on macOS.

**Acceptance Criteria**:

1. The system SHALL follow system appearance (light/dark) by default
2. The system SHALL provide a menu option to force light mode
3. The system SHALL provide a menu option to force dark mode
4. The system SHALL provide a menu option to follow system
5. WHEN theme changes THEN all views SHALL update immediately without restart
6. The theme preference SHALL persist across launches

**Independent Test**: Toggle theme options; verify persistence after restart; verify system appearance following.

---

### P1: Menu Bar Integration ⭐ MVP

**User Story**: As a macOS user, I want a native menu bar with standard macOS menus so that the app feels native.

**Why P1**: Native macOS apps must have a proper menu bar.

**Acceptance Criteria**:

1. The system SHALL display a menu bar with: App, File, Edit, View, Go, Window, Help
2. The File menu SHALL contain: New Folder (F7), Copy (F5), Move (F6), Delete (F8), View (F3), Edit (F4), Quit (Cmd+Q)
3. The Edit menu SHALL contain: Undo, Redo, Cut, Copy, Paste, Select All
4. The View menu SHALL contain: Sort submenu, Show Hidden Files (Cmd+.), Refresh (Cmd+R), Theme submenu
5. The Go menu SHALL contain: Back (Cmd+[), Forward (Cmd+]), Parent (Cmd+Up), Home, Computer
6. The Window menu SHALL contain: Minimize (Cmd+M), Zoom, Viewer, Editor
7. Keyboard shortcuts SHALL be visible in menu items

**Independent Test**: Verify all menu items present, shortcuts shown, actions work.

---

### P2: Path History Persistence

**User Story**: As a user, I want my navigation history to persist across app launches so that I can quickly return to recent locations.

**Why P2**: Improves workflow but not blocking for MVP.

**Acceptance Criteria**:

1. The system SHALL save panel path history to disk on app termination
2. The system SHALL load panel path history on app launch
3. The system SHALL limit history to 100 entries per panel
4. IF history file is corrupted THEN the system SHALL start with empty history

**Independent Test**: Navigate, quit, relaunch; verify back/forward history restored.

---

### P2: Volume/Drive Listing

**User Story**: As a user, I want to see mounted volumes in a quick-access location so that I can navigate to external drives easily.

**Why P2**: Common file manager feature; improves discoverability.

**Acceptance Criteria**:

1. The system SHALL display mounted volumes in the Go menu
2. The system SHALL display mounted volumes in a sidebar or toolbar
3. WHEN a volume is selected THEN the system SHALL navigate to its root
4. The system SHALL update volume list when volumes mount/unmount

**Independent Test**: Mount/unmount USB drive; verify appears/disappears in UI.

---

### P2: File Search/Filter in Panel

**User Story**: As a user, I want to filter files by name in the current directory so that I can find files quickly.

**Why P2**: Enhances usability for directories with many files.

**Acceptance Criteria**:

1. WHEN the user types in the panel THEN the system SHALL filter visible files by name (live filter)
2. The filter SHALL be case-insensitive
3. The filter SHALL match anywhere in the filename
4. Escape SHALL clear the filter

**Independent Test**: Type in panel; verify live filtering; Escape clears.

---

### P3: Bookmarks / Favorites

**User Story**: As a user, I want to bookmark frequently used directories so that I can access them quickly.

**Why P3**: Nice-to-have productivity feature.

**Acceptance Criteria**:

1. The system SHALL allow adding current directory to bookmarks (Cmd+D)
2. The system SHALL display bookmarks in a sidebar or menu
3. The system SHALL persist bookmarks across launches
4. The system SHALL allow removing bookmarks

**Independent Test**: Add/remove bookmarks; verify persistence; verify navigation.

---

## Edge Cases

1. IF a file is locked by another process THEN the system SHALL show "file in use" error with option to retry
2. IF disk is full during copy THEN the system SHALL show "disk full" error and offer to retry after space freed
3. IF a symlink points to non-existent target THEN the system SHALL show it as broken (distinct visual)
4. IF a directory has 10,000+ entries THEN the system SHALL load incrementally (pagination/virtualization)
5. IF the app loses focus during operation THEN the system SHALL continue operation in background
6. IF a volume is ejected during operation THEN the system SHALL cancel gracefully with error
7. IF a file path exceeds system limits THEN the system SHALL show appropriate error

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|----------------|-------|-------|--------|
| SWIFT-01 | P1: Project Foundation | Execute | Verified |
| SWIFT-02 | P1: Project Foundation | Design | Pending |
| SWIFT-03 | P1: Project Foundation | Design | Pending |
| SWIFT-04 | P1: Project Foundation | Design | Pending |
| SWIFT-05 | P1: Project Foundation | Execute | Verified |
| FS-01 | P1: File System Service | Design | Pending |
| FS-02 | P1: File System Service | Design | Pending |
| FS-03 | P1: File System Service | Design | Pending |
| FS-04 | P1: File System Service | Design | Pending |
| FS-05 | P1: File System Service | Design | Pending |
| FS-06 | P1: File System Service | Design | Pending |
| FS-07 | P1: File System Service | Design | Pending |
| FS-08 | P1: File System Service | Design | Pending |
| FS-09 | P1: File System Service | Design | Pending |
| FS-10 | P1: File System Service | Design | Pending |
| FS-11 | P1: File System Service | Design | Pending |
| FS-12 | P1: File System Service | Design | Pending |
| FS-13 | P1: File System Service | Design | Pending |
| FO-01 | P1: File Operations | Design | Pending |
| FO-02 | P1: File Operations | Design | Pending |
| FO-03 | P1: File Operations | Design | Pending |
| FO-04 | P1: File Operations | Design | Pending |
| FO-05 | P1: File Operations | Design | Pending |
| FO-06 | P1: File Operations | Design | Pending |
| FO-07 | P1: File Operations | Design | Pending |
| FO-08 | P1: File Operations | Design | Pending |
| FO-09 | P1: File Operations | Design | Pending |
| FO-10 | P1: File Operations | Design | Pending |
| FO-11 | P1: File Operations | Design | Pending |
| FO-12 | P1: File Operations | Design | Pending |
| FO-13 | P1: File Operations | Design | Pending |
| FO-14 | P1: File Operations | Design | Pending |
| FO-15 | P1: File Operations | Design | Pending |
| FO-16 | P1: File Operations | Design | Pending |
| FV-01 | P1: File Viewer | Design | Pending |
| FV-02 | P1: File Viewer | Design | Pending |
| FV-03 | P1: File Viewer | Design | Pending |
| FV-04 | P1: File Viewer | Design | Pending |
| FV-05 | P1: File Viewer | Design | Pending |
| FV-06 | P1: File Viewer | Design | Pending |
| FV-07 | P1: File Viewer | Design | Pending |
| FV-08 | P1: File Viewer | Design | Pending |
| ED-01 | P1: Text Editor | Design | Pending |
| ED-02 | P1: Text Editor | Design | Pending |
| ED-03 | P1: Text Editor | Design | Pending |
| ED-04 | P1: Text Editor | Design | Pending |
| ED-05 | P1: Text Editor | Design | Pending |
| ED-06 | P1: Text Editor | Design | Pending |
| ED-07 | P1: Text Editor | Design | Pending |
| ED-08 | P1: Text Editor | Design | Pending |
| ED-09 | P1: Text Editor | Design | Pending |
| ED-10 | P1: Text Editor | Design | Pending |
| KN-01 | P1: Keyboard Navigation | Design | Pending |
| KN-02 | P1: Keyboard Navigation | Design | Pending |
| KN-03 | P1: Keyboard Navigation | Design | Pending |
| KN-04 | P1: Keyboard Navigation | Design | Pending |
| KN-05 | P1: Keyboard Navigation | Design | Pending |
| KN-06 | P1: Keyboard Navigation | Design | Pending |
| KN-07 | P1: Keyboard Navigation | Design | Pending |
| KN-08 | P1: Keyboard Navigation | Design | Pending |
| KN-09 | P1: Keyboard Navigation | Design | Pending |
| KN-10 | P1: Keyboard Navigation | Design | Pending |
| KN-11 | P1: Keyboard Navigation | Design | Pending |
| KN-12 | P1: Keyboard Navigation | Design | Pending |
| TH-01 | P1: Theme Support | Design | Pending |
| TH-02 | P1: Theme Support | Design | Pending |
| TH-03 | P1: Theme Support | Design | Pending |
| TH-04 | P1: Theme Support | Design | Pending |
| TH-05 | P1: Theme Support | Design | Pending |
| TH-06 | P1: Theme Support | Design | Pending |
| MB-01 | P1: Menu Bar | Design | Pending |
| MB-02 | P1: Menu Bar | Design | Pending |
| MB-03 | P1: Menu Bar | Design | Pending |
| MB-04 | P1: Menu Bar | Design | Pending |
| MB-05 | P1: Menu Bar | Design | Pending |
| MB-06 | P1: Menu Bar | Design | Pending |
| MB-07 | P1: Menu Bar | Design | Pending |
| PH-01 | P2: Path History Persistence | Design | Pending |
| PH-02 | P2: Path History Persistence | Design | Pending |
| PH-03 | P2: Path History Persistence | Design | Pending |
| PH-04 | P2: Path History Persistence | Design | Pending |
| VL-01 | P2: Volume Listing | Design | Pending |
| VL-02 | P2: Volume Listing | Design | Pending |
| VL-03 | P2: Volume Listing | Design | Pending |
| VL-04 | P2: Volume Listing | Design | Pending |
| SF-01 | P2: Search/Filter | Design | Pending |
| SF-02 | P2: Search/Filter | Design | Pending |
| SF-03 | P2: Search/Filter | Design | Pending |
| SF-04 | P2: Search/Filter | Design | Pending |
| BM-01 | P3: Bookmarks | Design | Pending |
| BM-02 | P3: Bookmarks | Design | Pending |
| BM-03 | P3: Bookmarks | Design | Pending |
| BM-04 | P3: Bookmarks | Design | Pending |

**Coverage:** 87 total, 2 mapped to tasks, 85 unmapped ⚠️

---

## Success Criteria

- [ ] `swift build` succeeds on clean clone
- [ ] `swift test` passes all unit tests (>80% coverage on core logic)
- [ ] App launches and displays dual-pane file browser
- [ ] All P1 keyboard shortcuts functional
- [ ] Copy/move/delete/mkdir operations work with conflict resolution
- [ ] File viewer opens text, image, and binary files
- [ ] Text editor opens, edits, saves text files with dirty tracking
- [ ] Theme follows system / manual override / persists
- [ ] Native menu bar with all required menus and shortcuts
- [ ] Path history persists across launches (P2)
- [ ] Volume listing updates on mount/unmount (P2)
- [ ] Live filtering in panels works (P2)
- [ ] Bookmarks add/remove/persist/navigate (P3)