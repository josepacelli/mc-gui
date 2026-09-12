# LESSONS - auto-maintained by scripts/lessons.py

> Machine-owned. Do NOT hand-edit. Changes are overwritten on the next `lessons.py` write.
> Canonical state lives in `.specs/lessons.json`. Edit lessons only via the script.
> promote_threshold=2 distinct features · window_days=45 · quarantine_threshold=2

## Confirmed (load these at Specify/Design)

Corroborated across multiple features. Safe to apply as guidance.

_none_

## Candidates (under observation - do NOT load as guidance yet)

Seen once or not yet corroborated. Tracked, not trusted.

### L-001 - Theme structural tests must assert Light and Dark token values differ, not only that the key exists in each variant.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `src/McGui.App/Themes.axaml` · harmful: 0
- features: theming
- evidence: tests/McGui.App.Tests/Theming/ThemeResourcesTests.cs:99 (src/McGui.App/Themes.axaml)
- last seen: 2026-09-05T20:20:53Z

### L-002 - Do not spec a XAML color literal as a build failure - Avalonia compiles literals; assert the structural scan rejects them.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `Avalonia` · harmful: 0
- features: theming
- evidence: .specs/features/theming/spec.md:97 (Avalonia)
- last seen: 2026-09-05T20:20:56Z

### L-003 - Avalonia 12 removed the MenuBar control; use the top-level Menu control for a menu bar.
- signal: `spec_deviation` · recurrence: 1 feature(s) · scope: `Avalonia` · harmful: 0
- features: theming
- evidence: .specs/features/theming/tasks.md:191 (Avalonia)
- last seen: 2026-09-05T20:20:58Z

### L-004 - Row view-models that gate a spec-visible column value (empty size for directory and '..' rows) need an explicit unit test on the derived property; a XAML binding alone does not discriminate a regression.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `App view-row layer` · harmful: 0
- features: panel-icons-dotdot
- evidence: M6: src/McGui.App/ViewModels/PanelEntryRow.cs:15 (App view-row layer)
- last seen: 2026-09-05T21:53:25Z

### L-005 - Every AC that hides or shows a UI column value (not just formats it) must map to an App-layer unit assertion on the row/view-model, never only to the view file.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `spec coverage` · harmful: 0
- features: panel-icons-dotdot
- evidence: PII-15: spec.md size AC 2 (spec coverage)
- last seen: 2026-09-05T21:53:29Z

### L-006 - Axaml structural order tests must anchor ALL 5 top-level headers in relative sequence (Left first, Right last); text-window split on first _Left lets a Left<->File swap pass.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `MainWindow.axaml tests` · harmful: 0
- features: mc-menubar
- evidence: tests/McGui.App.Tests/McMenuDefinitionsTests.cs:161 (MainWindow.axaml tests)
- last seen: 2026-09-05T22:17:05Z

### L-007 - Containment-of-node tests need real nesting (item before Options' closing tag), not a substring window bounded by the NEXT menu header; top-level Theme placed between Options and Right evades the check.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `MainWindow.axaml tests` · harmful: 0
- features: mc-menubar
- evidence: tests/McGui.App.Tests/McMenuDefinitionsTests.cs:175 (MainWindow.axaml tests)
- last seen: 2026-09-05T22:17:05Z

### L-008 - CI portability beats repo-local convenience: when a build dependency (PIL) is dropped from packaging, update the spec text or add a SPEC_DEVIATION marker at the same commit — stale spec lines mislead the Verifier.
- signal: `spec_deviation` · recurrence: 1 feature(s) · harmful: 0
- features: macos-installer
- evidence: spec.md:38,95
- last seen: 2026-09-05T22:55:01Z

### L-009 - When a UI dimension has no Avalonia sizing API to confirm it (e.g. a native title-bar height estimate), pick a literal value, flag it as an unverified assumption, and treat human visual UAT as a non-blocking follow-up once the underlying mechanism is structurally tested - not as a blocking code defect.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `Avalonia window chrome` · harmful: 0
- features: macos-native-chrome
- evidence: P1 AC3 (.specs/features/macos-native-chrome/validation.md round 3) (Avalonia window chrome)
- last seen: 2026-09-06T11:34:50Z

### L-010 - Before marking a UI flow verified, grep the source tree for real callers of its ViewModel/dialog outside its own file and tests - a fully unit-tested component with zero callers in the shipped app is not wired, regardless of test coverage.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `swiftui-viewmodel-wiring` · harmful: 0
- features: convert-to-swift-swiftui
- evidence: FO-05 (swiftui-viewmodel-wiring)
- last seen: 2026-09-10T01:07:45Z

### L-011 - Do not mark a requirement Verified in the traceability table until the specific described behavior is confirmed present in source - a sibling feature working is not evidence that this one exists.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `requirement-traceability` · harmful: 0
- features: convert-to-swift-swiftui
- evidence: FV-02 (requirement-traceability)
- last seen: 2026-09-10T01:07:45Z

### L-012 - When spec.md asks for an explicit user-facing 'offer to retry' action, an automatic internal retry-then-fail is not equivalent - implement or flag the missing retry affordance separately.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `error-handling` · harmful: 0
- features: convert-to-swift-swiftui
- evidence: Edge Cases 1-2 (error-handling)
- last seen: 2026-09-10T01:07:45Z

### L-013 - When two key bindings share one handler closure, verify each key's full spec-required behavior is implemented, not just the behavior the keys have in common.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `keyboard-handling` · harmful: 0
- features: convert-to-swift-swiftui
- evidence: KN-06 (validation.md) (keyboard-handling)
- last seen: 2026-09-10T16:07:28Z

### L-014 - When fixing a gap would require a protocol-level signature change out of the current fix pass's budget, defer it explicitly with a SPEC_DEVIATION comment rather than applying a half-measure that changes nothing observable.
- signal: `spec_deviation` · recurrence: 1 feature(s) · scope: `fix-cycle-scoping` · harmful: 0
- features: convert-to-swift-swiftui
- evidence: Edge Case 4 (FileSystemServiceImpl.swift:58-69) (fix-cycle-scoping)
- last seen: 2026-09-10T16:07:28Z

### L-015 - Private SwiftUI view glue (key-dispatch closures, cursor-state helpers) survives targeted mutation with no XCUITest harness in place - treat it as an accepted coverage gap only when the pure function it calls is independently unit-tested; otherwise wire a real regression test.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `swiftui-view-glue` · harmful: 0
- features: convert-to-swift-swiftui
- evidence: PanelView.swift:365-370,701-708 (validation.md iteration 2) (swiftui-view-glue)
- last seen: 2026-09-10T16:19:44Z

### L-016 - Stage and commit new/edited test files in the same commit as the implementation task; verify with 'git show --stat <sha>' before marking a task done, not just a local swift test run.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `process/commit-discipline` · harmful: 0
- features: drag-drop-copy
- evidence: commits 6992edc,5464954,cf62f73,9ff1674,e0cf1f4,35522c4 (process/commit-discipline)
- last seen: 2026-09-12T01:45:58Z

### L-017 - When an async, state-mutating orchestration method (like beginCopyOrMove/handleDrop) composes already-tested pure helpers, extract its own decision output (e.g. dialog params) into one more static testable function rather than leaving the composition itself untestable and unverified.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `MCGuiUI/Views/PanelView` · harmful: 0
- features: drag-drop-copy
- evidence: DND-02,DND-07 - PanelView.swift handleDrop (private async) (MCGuiUI/Views/PanelView)
- last seen: 2026-09-12T01:45:58Z

### L-018 - When a spec's edge case is satisfied by value-type/immutability guarantees rather than explicit branching, still add a test that mutates shared state between capture and use to make the guarantee explicit and regression-proof.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `MCGuiUI/Views/PanelView` · harmful: 1
- features: drag-drop-copy
- evidence: DND-12 - dragPayload/PanelView.swift (MCGuiUI/Views/PanelView)
- last seen: 2026-09-12T01:54:59Z

### L-019 - On a case-insensitive filesystem (default macOS), 'git add Tests/...' silently no-ops when the tracked path is 'tests/...' (lowercase) - no error, nothing staged; after adding new test files, run 'git status' or 'git show --stat <sha>' to confirm the exact tracked casing was staged, not just that swift test passed locally.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `process/git-case-sensitivity` · harmful: 0
- features: drag-drop-copy
- evidence: commit 9ce11da message; git ls-files tests/MCGuiUITests/Views/DraggedFileURLsTests.swift (process/git-case-sensitivity) (process/git-case-sensitivity)
- last seen: 2026-09-12T01:55:07Z

### L-020 - When a spec edge case is already satisfied because a pure static function takes the mutable state as a by-value parameter (Swift value-type copy-on-call), do not add a test that mutates the caller's variable after the call and asserts the earlier result is unaffected - that only proves Swift's own call-by-value semantics, a Check C anti-pattern (testing framework/language behavior, not app logic); the existing input/output test of the pure function is sufficient evidence, and note in validation.md that the edge case is closed by construction.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `MCGuiUI/Views/PanelView` · harmful: 0
- features: drag-drop-copy
- evidence: DND-12 iteration 2 - dragPayload/PanelView.swift:621-628 (corrects L-018) (MCGuiUI/Views/PanelView)
- last seen: 2026-09-12T01:55:15Z

### L-021 - When a spec requirement is conditional on a data field a view model already exposes (e.g. isSymlink/symlinkTarget), add a view-model-level test for that branch even if the surrounding feature is otherwise UI-only and untestable.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `MCGuiUI` · harmful: 0
- features: context-menu-actions
- evidence: CTXM-17 (MCGuiUI)
- last seen: 2026-09-12T02:30:20Z

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
