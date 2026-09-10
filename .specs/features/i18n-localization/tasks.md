# Internationalization (i18n) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow
its Execute flow and Critical Rules.** Do not search for skill files by filesystem path.
The skill is the source of truth for the full flow (per-task cycle, sub-agent
delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/i18n-localization/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Generated from codebase sampling - confirm before Execute. Guidelines found: none
> (no `AGENTS.md`/`CONTRIBUTING.md`/testing-standards doc in this repo); this project's
> own established convention (confirmed by sampling `OperationProgressTrackerTests.swift`,
> `UserMenuRunnerTests.swift`, `PanelViewFileOperationsTests.swift`, and this session's
> `.specs/LESSONS.md` L-015) is: `swift test` (Swift Testing `@Test`) unit tests for
> service/business logic, and **no** direct unit tests for SwiftUI `View.body` text
> (thin declarative glue, previously flagged by the Verifier as untestable private view
> state) - that convention is treated as the floor/ceiling for this feature too.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Localization core (`Package.swift` resources, `Bundle.module` key-set parity across the 4 `.lproj` per target) | unit | Every target's pt-BR/pt-PT/es key set exactly equals its en (base) key set - no missing, no orphaned keys (I18N-09) | `tests/MCGuiUITests/Localization/LocalizationCoverageTests.swift` | `swift test --filter LocalizationCoverageTests` |
| `FileSystemServiceError: LocalizedError` | unit | One assertion per error case × per locale (6 cases × 4 languages), loading each language's `.lproj` sub-bundle directly (not dependent on the test host's actual system locale) | `tests/MCGuiMacOSTests/FileSystem/FileSystemServiceErrorLocalizationTests.swift` | `swift test --filter FileSystemServiceErrorLocalizationTests` |
| SwiftUI View/Dialog string extraction (PanelView, CopyMoveDialog, TopBar, AppCommands, HelpWindow, ...) | none | Covered transitively: every key these files reference must exist, translated, in all 4 languages, or the Localization core test (above) fails. Matches this project's existing precedent of not unit-testing SwiftUI `body` text directly. | N/A | build gate only |
| Packaging (`build-macos.sh`, `Info.plist`) | none | Mechanical shell/plist change, verified by actually running the build and inspecting the resulting `.app`'s `Contents/Resources` for the copied `.bundle` dirs - not a Swift test | N/A | `./packaging/build-macos.sh 0.1.0` + `find` verification |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Fast local iteration on a Localization-core or error-message task, before the final gate | `swift build && swift test --filter Localization` |
| Full | Every task's actual completion gate (matches this project's established full-suite-per-commit practice throughout this session) | `swift build && swift test` |
| Build | Packaging-script/`Info.plist` tasks, and the final verification task | `./packaging/build-macos.sh 0.1.0` then `find "artifacts/Midnight Commander GUI.app/Contents/Resources" -name "*.bundle"` |

---

## Shared Glossary (T2)

Every task below translating UI text MUST reuse `.specs/features/i18n-localization/glossary.md`
(created in T2) for any of its recurring terms (File, Folder, Copy, Move, Delete, Cancel,
OK, Destination, Selection, Confirm, Overwrite, Skip, Rename, ...) instead of choosing its
own wording - this is what keeps pt-BR/pt-PT/es terminology consistent across 20+ files
translated as separate tasks (and, if delegated, separate sub-agent workers).

---

## Execution Plan

Phases are ordered and run sequentially - each phase completes before the next begins,
tasks within a phase execute in order.

### Phase 1: Localization Infrastructure

```
T1 → T2 → T3 → T4 → T5
```

### Phase 2: Panel + Core File-Operation Dialogs

```
T6 → T7 → T8 → T9 → T10 → T11 → T12
```

### Phase 3: Chrome + Secondary Windows

```
T13 → T14 → T15 → T16 → T17 → T18 → T19
```

### Phase 4: Native Menu, App Shell, Help

```
T20 → T21 → T22 → T23 → T24
```

### Phase 5: Packaging Verification

```
T25
```

---

## Task Breakdown

### T1: Wire `resources:` into `Package.swift`, verify `Bundle.module` resolution

**What**: Add `resources: [.process("Resources")]` to the `MCGuiUI`, `MCGuiApp`, and
`MCGuiMacOS` targets; create `Resources/en.lproj/Localizable.strings` in each with one
placeholder key; `swift build` and inspect the actual generated `.bundle` name/location
in the bin path to confirm the Architecture Overview's assumption before anything depends
on it (Risk 3 in design.md).
**Where**: `Package.swift`, `Sources/MCGuiUI/Resources/en.lproj/Localizable.strings`,
`Sources/MCGuiApp/Resources/en.lproj/Localizable.strings`,
`Sources/MCGuiMacOS/Resources/en.lproj/Localizable.strings`
**Depends on**: None
**Reuses**: N/A - foundational
**Requirement**: I18N-08

**Tools**: MCP: NONE. Skill: NONE.

**Done when**:
- [x] All 3 targets declare `resources: [.process("Resources")]`
- [x] `swift build` succeeds and produces one `MCGui_<Target>.bundle` per target next to the executable
- [x] A one-line note in this task's commit message (or a code comment) records the actual observed bundle name/path, confirming or correcting design.md's assumption

**Tests**: none (infra scaffolding, no logic yet)
**Gate**: build

**Confirmed (empirically observed)**: `swift build --show-bin-path` →
`.build/arm64-apple-macosx/debug`. Each target produces `MCGui_<TargetName>.bundle`
flat in that directory (`MCGui_MCGuiUI.bundle`, `MCGui_MCGuiApp.bundle`,
`MCGui_MCGuiMacOS.bundle`), matching design.md's assumption exactly. Each bundle
contains `en.lproj/Localizable.strings` + a generated `Info.plist`. `swift build`
also required `defaultLocalization: "en"` on the package manifest (SPM error otherwise:
`manifest property 'defaultLocalization' not set; it is required in the presence of
localized resources`) - not called out in design.md, added in this task.

**Status**: ✅ Complete

---

### T2: Write the shared translation glossary

**What**: A short reference table (English term → pt-BR / pt-PT / es) for every recurring
UI term expected to appear in 3+ files (File, Folder, Copy, Move, Delete, Rename, Cancel,
OK, Confirm, Destination, Selection, Overwrite, Skip, Background, Options, Help, Search,
Bookmarks, ...), so every later translation task/worker uses the same wording.
**Where**: `.specs/features/i18n-localization/glossary.md`
**Depends on**: T1
**Reuses**: N/A
**Requirement**: N/A (supports I18N-01, I18N-02, I18N-04's consistency, not a user-facing requirement itself)

**Tools**: MCP: NONE. Skill: NONE.

**Done when**:
- [x] Table covers every term expected to recur across ≥3 files, in pt-BR, pt-PT (with real divergence from pt-BR noted, e.g. ficheiro/arquivo), and es
- [x] Committed as a plain doc, not code (not built or tested)

**Tests**: none
**Gate**: none (docs only)

**Status**: ✅ Complete

---

### T3: Update `packaging/build-macos.sh` and `packaging/Info.plist`

**What**: Add a step copying every `MCGui_<Target>.bundle` (using T1's confirmed actual
name) from the `swift build` bin path into `$APP_DIR/Contents/Resources/`; add
`CFBundleLocalizations` (en, pt-BR, pt-PT, es) and `CFBundleDevelopmentRegion` (en) to
`Info.plist`.
**Where**: `packaging/build-macos.sh`, `packaging/Info.plist`
**Depends on**: T2
**Reuses**: The script's existing icon-copy step (same copy-into-`Contents/Resources` pattern)
**Requirement**: I18N-08

**Tools**: MCP: NONE. Skill: NONE.

**Done when**:
- [x] `./packaging/build-macos.sh 0.1.0` succeeds
- [x] `find "artifacts/Midnight Commander GUI.app/Contents/Resources" -name "*.bundle"` lists one bundle per resource-bearing target
- [x] `plutil -lint` on the produced `Info.plist` passes (existing bundle-verify step already does this)

**Tests**: none
**Gate**: build

**Confirmed**: `MCGui_MCGuiUI.bundle`, `MCGui_MCGuiMacOS.bundle`, `MCGui_MCGuiApp.bundle`
all present under `Contents/Resources/` after a real `./packaging/build-macos.sh 0.1.0`
run. `CFBundleDevelopmentRegion` was already `en` in `Info.plist` (pre-existing, not
added by this task); `CFBundleLocalizations` (en, pt-BR, pt-PT, es) added.

**Status**: ✅ Complete

---

### T4: `LocalizationCoverageTests` (I18N-09)

**What**: A Swift Testing suite that, for each of `MCGuiUI`, `MCGuiApp`, `MCGuiMacOS`,
parses `en.lproj/Localizable.strings` and each of `pt-BR`/`pt-PT`/`es`'s
`Localizable.strings` (skip comments, split on ` = `, strip the trailing `;`), and
asserts the two key sets are exactly equal.
**Where**: `tests/MCGuiUITests/Localization/LocalizationCoverageTests.swift`
**Depends on**: T3
**Reuses**: N/A - new parsing helper, small enough not to warrant extracting a shared utility
**Requirement**: I18N-09

**Tools**: MCP: NONE. Skill: NONE.

**Done when**:
- [x] One `@Test` per (target × language) pair asserting exact key-set equality against that target's en.lproj
- [x] Currently green (T1 seeded matching placeholder keys in all languages it created - if T1 only created `en.lproj`, this task also creates the matching empty/placeholder `pt-BR`/`pt-PT`/`es.lproj` files so the suite is green from this task onward, not red until some later task)
- [x] `swift test --filter LocalizationCoverageTests` passes

**Tests**: unit (this task *is* the test)
**Gate**: quick

**Confirmed**: `@Test(arguments: targets, languages)` (Swift Testing's cartesian-product
form) generates the 9 (target × language) cases in one function; parser verified to
actually catch a divergence (manually appended an orphaned key to a pt-BR.lproj,
confirmed the suite fails, reverted). `swift test`: 311 passed, 0 failed (was 310).

**Status**: ✅ Complete

---

### T5: `FileSystemServiceError: LocalizedError` + its test

**What**: Conform `FileSystemServiceError` to `LocalizedError` with an `errorDescription`
built from `String(format: NSLocalizedString(key, bundle: .module, comment:), args...)`
per case; add the 6 keys (`.permissionDenied`, `.alreadyExists`, `.fileInUse`,
`.insufficientDiskSpace`, `.volumeDisconnected`, `.pathTooLong`) to `MCGuiMacOS`'s 4
`Localizable.strings`; replace `FileSystemServiceImpl.describe(_:)`'s
`String(describing: typed)` dump with the new `errorDescription`.
**Where**: `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift`,
`Sources/MCGuiMacOS/Resources/{en,pt-BR,pt-PT,es}.lproj/Localizable.strings`
**Depends on**: T4
**Reuses**: `.specs/features/i18n-localization/glossary.md` (T2) for consistent wording
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04 (error messages), addresses design.md's Risk 1

**Tools**: MCP: NONE. Skill: NONE.

**Done when**:
- [x] All 6 cases have a localized `errorDescription` in all 4 languages
- [x] `describe(_:)` no longer calls `String(describing: typed)` for `FileSystemServiceError`
- [x] `FileSystemServiceErrorLocalizationTests.swift` asserts each case's exact text per locale by loading that language's `.lproj` sub-bundle directly
- [x] `swift test` passes (306+ existing tests still pass, plus the new ones)

**Tests**: unit
**Gate**: full

**Confirmed / deviation notes**:
- SPM's resource processing lowercases the region subtag of `.lproj` directory names
  on disk (`pt-BR.lproj` -> `pt-br.lproj`, `pt-PT.lproj` -> `pt-pt.lproj`); `Bundle`'s
  own runtime language negotiation (used by `errorDescription`'s
  `NSLocalizedString(bundle: .module, ...)`) matches locale identifiers
  case-insensitively regardless, so production behavior is unaffected - only the
  test's direct-path lookup (`Bundle.module.path(forResource: "pt-BR", ofType: "lproj")`)
  needed a lowercase fallback. Also found empirically: a `Bundle(path:)` rooted at a
  bare `.lproj` directory resolves `localizedString(forKey:)` back to the base/English
  table rather than that directory's own table - the test instead reads
  `Localizable.strings` directly via `NSDictionary(contentsOfFile:)` for a
  deterministic, locale-independent lookup.
- Fixed 1 pre-existing test broken by this task's change:
  `FileSystemServiceImplCopyMoveTests.swift`'s "copy reports a typed fileInUse
  failure..." asserted `reason.contains("fileInUse")` (the old case-name dump);
  updated to compare against `FileSystemServiceError.fileInUse(sourceEntry.path)
  .errorDescription` (behavior-focused, not text-focused).

**Status**: ✅ Complete

---

### T6: Extract `PanelView.swift`'s own literal strings

**What**: Replace `PanelView.swift`'s own UI-facing literals (the FO-15 `fo15Message`
template, any inline `Text`/context-menu labels not already delegated to a dialog file)
with `String(localized:)`/`NSLocalizedString`+`String(format:)` lookups; add the keys to
`MCGuiUI`'s 4 `Localizable.strings`.
**Where**: `Sources/MCGuiUI/Views/PanelView.swift`
**Depends on**: None
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**:
- [x] Every real UI string in the file (excluding SF Symbol names/format specifiers) is a localized lookup
- [x] Any existing test asserting the old literal English text is updated (behavior-focused, not text-focused, or pinned to the en table)
- [x] `swift test` passes

**Tests**: none (view glue, per matrix) - but update any existing test broken by the change, in this same task
**Gate**: full

**Confirmed**: 4 keys extracted (`panel.footer.fileCount`, `panel.footer.selectionCount`,
`panel.operationFailure.single`, `panel.operationFailure.multiple`), all parameterized
(`String(format:)` + `NSLocalizedString`). `entry.name` (context menu) and
`viewModel.currentPath.path` (header) are file paths/user data, not UI text - left as-is
per Out of Scope. No existing test asserted the old literal text (`fo15Message` tests use
`.contains()` on path/reason substrings only) - none needed updating. `swift test`: 318
passed, 0 failed (was 311).

**Status**: ✅ Complete

---

### T7: Extract `CopyMoveDialog.swift`

**What**: Title, destination field label, the 3 option toggles, and the OK/Background/Cancel buttons.
**Where**: `Sources/MCGuiUI/Views/CopyMoveDialog.swift`
**Depends on**: T6
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**:
- [x] Every UI string extracted to all 4 languages
- [x] Any broken existing test updated in this task
- [x] `swift test` passes

**Tests**: none / update existing
**Gate**: full

**Confirmed**: 10 keys extracted (title/header/destination/3 toggles/3 buttons). Header
combines the localized mode word with a singular/plural item-count template (no
`.stringsdict` per AD-005, so singular/plural are two full `.strings` templates, matching
the fo15Message pattern from T6). No existing test asserted view text (`CopyMoveDialogViewModelTests`
covers ViewModel logic only) - none needed updating. `swift test`: 318 passed, 0 failed.

**Status**: ✅ Complete

---

### T8: Extract `ConflictDialog.swift`

**What**: Overwrite/Skip/Rename/Cancel conflict-resolution UI text.
**Where**: `Sources/MCGuiUI/Views/ConflictDialog.swift`
**Depends on**: T7
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
- [x] Every UI string extracted to all 4 languages
- [x] Any broken existing test updated in this task
- [x] `swift test` passes

**Tests**: none / update existing
**Gate**: full

**Confirmed**: 5 keys extracted (header + Cancel/Skip/Rename/Overwrite buttons); header
uses a parameterized `%1$@` with curly quotes, matching T5's `FileSystemServiceError`
message convention. `ConflictDialogViewModelTests` covers ViewModel logic only, no view
text assertions - none needed updating. `swift test`: 318 passed, 0 failed.

**Status**: ✅ Complete

---

### T9: Extract `MkdirDialog.swift`

**What**: New-folder dialog's label/buttons.
**Where**: `Sources/MCGuiUI/Views/MkdirDialog.swift`
**Depends on**: T8
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T10: Extract `DeleteConfirmDialog.swift`

**What**: Delete-confirmation UI text.
**Where**: `Sources/MCGuiUI/Views/DeleteConfirmDialog.swift`
**Depends on**: T9
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T11: Extract `SaveChangesDialog.swift`

**What**: Unsaved-changes prompt UI text.
**Where**: `Sources/MCGuiUI/Views/SaveChangesDialog.swift`
**Depends on**: T10
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T12: Extract `ProgressDialog.swift`

**What**: "Copying…"/"Scanning…"/"File N of M"/byte-count/ETA/Cancel text - includes the
`(String(format:))`-based "File %1$d of %2$d" template.
**Where**: `Sources/MCGuiUI/Views/ProgressDialog.swift`
**Depends on**: T11
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04, I18N-07 (locale-aware byte/ETA formatting - confirm `ByteCountFormatter`/`Int(eta)` already respect the resolved locale, no extra work needed beyond the surrounding labels)

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7, plus explicit confirmation that `ByteCountFormatter.string` output changes with `Locale.current`)
**Tests**: none / update existing
**Gate**: full

---

### T13: Extract `TopBar.swift`

**What**: Left/File/Command/Options/Right menu bar labels and their items (largest of the chrome files - 22 candidate strings).
**Where**: `Sources/MCGuiUI/Views/TopBar.swift`
**Depends on**: None
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T14: Extract `ButtonBar.swift`

**What**: F1-F10 button row labels.
**Where**: `Sources/MCGuiUI/Views/ButtonBar.swift`
**Depends on**: T13
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T15: Extract `MainWindow.swift`

**What**: Bookmarks-popover trigger label and any other inline literal in the root window view.
**Where**: `Sources/MCGuiUI/Views/MainWindow.swift`
**Depends on**: T14
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing (note: `MainWindow volumes` test suite exists - check it doesn't assert literal UI text)
**Gate**: full

---

### T16: Extract `BookmarksView.swift`

**What**: Bookmarks popover's own list/add/remove UI text (never the bookmark names themselves - those are user data, I18N-12).
**Where**: `Sources/MCGuiUI/Views/BookmarksView.swift`
**Depends on**: T15
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T17: Extract `UserMenuView.swift`

**What**: User Menu's own list/add/remove/run UI text (never the user's own item labels/commands - I18N-12).
**Where**: `Sources/MCGuiUI/Views/UserMenuView.swift`
**Depends on**: T16
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T18: Extract `ViewerWindow.swift`

**What**: F3 viewer's own chrome (not the viewed file's content).
**Where**: `Sources/MCGuiUI/Views/ViewerWindow.swift`
**Depends on**: T17
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T19: Extract `EditorWindow.swift`

**What**: F4 editor's own chrome (largest of the window files after Help/AppCommands - 21 candidate strings; not the edited file's content).
**Where**: `Sources/MCGuiUI/Views/EditorWindow.swift`
**Depends on**: T18
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing (`EditorWindowViewModel` tests exist - check for literal-text assertions)
**Gate**: full

---

### T20: Extract `AppCommands.swift` (native menu bar)

**What**: Every native `Button`/menu title in the App/File/Edit/View/Go/Window/Help menus
(largest single file - 36 candidate strings).
**Where**: `Sources/MCGuiUI/Commands/AppCommands.swift`
**Depends on**: None
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7, plus: keyboard shortcuts like Cmd+Q/Cmd+Z themselves are never translated, only the menu item's label text)
**Tests**: none / update existing
**Gate**: full

---

### T21: Extract `WindowManager.swift` (MCGuiApp)

**What**: Window titles ("Copying…", "Help", "User Menu") and the `NSAlert` "Could Not
Open %@" message.
**Where**: `Sources/MCGuiApp/WindowManager.swift`
**Depends on**: T20
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7 - note: uses `MCGuiApp`'s own `.lproj`, not `MCGuiUI`'s)
**Tests**: none / update existing
**Gate**: full

---

### T22: Extract `HelpWindow.swift`

**What**: The full static keyboard-shortcut reference content (largest translation volume
in the app - 24 candidate strings, likely more once nested content is counted).
**Where**: `Sources/MCGuiUI/Views/HelpWindow.swift`
**Depends on**: T21
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T23: Extract `SupportComponents.swift` and `ThemeMenu.swift`

**What**: `ThemeMenu`'s Follow System/Light/Dark labels, and any genuine UI text in
`SupportComponents.swift` (most of its grep hits are SF Symbol names like `folder.fill`,
not UI text - audit before extracting, only translate what's real).
**Where**: `Sources/MCGuiUI/Views/ThemeMenu.swift`, `Sources/MCGuiUI/Components/SupportComponents.swift`
**Depends on**: T22
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04

**Tools**: MCP: NONE. Skill: NONE.

**Done when**: (same shape as T7)
**Tests**: none / update existing
**Gate**: full

---

### T24: Sweep remaining files for missed literals

**What**: Re-run the string-literal grep sweep from design/discovery across
`Sources/MCGuiUI`, `Sources/MCGuiApp`, `Sources/MCGuiMacOS`; extract anything real that
T5-T23 didn't cover (e.g. `SyntaxHighlighter.swift` if it turns out to hold any genuine
UI text distinct from its keyword arrays, which stay untranslated per I18N-13).
**Where**: Any file with leftover literals
**Depends on**: T23
**Reuses**: Glossary (T2)
**Requirement**: I18N-01, I18N-02, I18N-03, I18N-04, I18N-13

**Tools**: MCP: NONE. Skill: NONE.

**Done when**:
- [ ] A fresh literal-string grep across the 3 targets shows no remaining real UI text (SF Symbol names, format specifiers, and syntax-highlighter keywords excluded and documented as intentional)
- [ ] `swift test` passes

**Tests**: none / update existing
**Gate**: full

---

### T25: Rebuild DMG, verify packaging, hand off for visual UAT

**What**: Run `./packaging/build-macos.sh 0.1.0`, mechanically confirm all `.bundle`
dirs are present in `Contents/Resources` (this agent cannot change macOS System Language
or visually inspect a locked screen - see design.md Success Criteria), then ask the user
to set each of the 4 System Languages and confirm visually per spec.md's Independent Test.
**Where**: N/A (verification task)
**Depends on**: None
**Reuses**: T3's packaging changes
**Requirement**: I18N-08 (final confirmation), Success Criteria in spec.md

**Tools**: MCP: NONE. Skill: NONE.

**Done when**:
- [ ] `swift build && swift test` passes (full suite)
- [ ] DMG built, `.bundle` dirs mechanically confirmed present
- [ ] User has confirmed at least Portuguese (Brazil) and one other language visually in the installed app

**Tests**: none (mechanical + user UAT)
**Gate**: build

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

Phase 1:  T1 → T2 → T3 → T4 → T5
Phase 2:  T6 → T7 → T8 → T9 → T10 → T11 → T12
Phase 3:  T13 → T14 → T15 → T16 → T17 → T18 → T19
Phase 4:  T20 → T21 → T22 → T23 → T24
Phase 5:  T25
```

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1 | 1 package config + verification | ✅ Granular |
| T2 | 1 doc | ✅ Granular |
| T3 | 2 packaging files, 1 concern (bundle copy + locale metadata) | ✅ Granular |
| T4 | 1 test file | ✅ Granular |
| T5 | 1 error type + its test | ✅ Granular |
| T6-T23 | 1 source file each (occasionally 2 tightly related small files, T23) | ✅ Granular |
| T24 | Sweep - bounded by "what T6-T23 missed," not open-ended | ✅ Granular |
| T25 | 1 verification pass | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | (phase start) | ✅ Match |
| T2 | None | T1 → T2 | ✅ Match (sequential within phase, no real dependency - order is arbitrary but both precede content tasks) |
| T3 | T1 | T2 → T3 | ✅ Match (sequential slot; true dependency is T1, satisfied by phase order) |
| T4 | T1 | T3 → T4 | ✅ Match |
| T5 | T1, T2 | T4 → T5 | ✅ Match |
| T6-T12 | T1, T2 (each) | Phase 2 chain | ✅ Match |
| T13-T19 | T1, T2 (each) | Phase 3 chain | ✅ Match |
| T20-T24 | T1, T2 (each); T24 also depends on T6-T23 | Phase 4 chain | ✅ Match |
| T25 | T24 | Phase 5 | ✅ Match |

No task depends on a later-phase task.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1 | Package config | none (infra) | none | ✅ OK |
| T2 | Docs | none | none | ✅ OK |
| T3 | Packaging script/plist | none (build gate only) | none | ✅ OK |
| T4 | Localization core | unit | unit | ✅ OK |
| T5 | `FileSystemServiceError` | unit | unit | ✅ OK |
| T6-T24 | SwiftUI View/Dialog string extraction | none (+ update existing tests if broken) | none / update existing | ✅ OK |
| T25 | Packaging verification | none (build gate only) | none | ✅ OK |

No violations - every "Tests: none" task matches the matrix's "none" designation for that
layer, and every extraction task explicitly commits to fixing any test it breaks in the
same task (never deferred).
