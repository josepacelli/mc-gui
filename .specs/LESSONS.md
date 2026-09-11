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

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
