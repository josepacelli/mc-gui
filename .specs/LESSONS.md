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

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
