# i18n-localization Validation

**Date**: 2026-09-10
**Spec**: `.specs/features/i18n-localization/spec.md`
**Diff range**: `bebd5b5..9acc2e7`
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status  | Notes |
| ---- | ------- | ----- |
| T1   | ✅ Done | `resources:` wired, bundle names confirmed |
| T2   | ✅ Done | Glossary doc committed |
| T3   | ✅ Done | Packaging bundle-copy step + `CFBundleLocalizations` |
| T4   | ✅ Done | `LocalizationCoverageTests` added, verified real (see Sensor) |
| T5   | ✅ Done | `FileSystemServiceError: LocalizedError` + test |
| T6-T24 | ✅ Done | One source file (or tightly related pair) each, per-file `swift test` gate |
| T25  | ✅ Done (mechanical) | DMG built, bundles verified present; visual System-Language UAT explicitly left to the user (no interactive macOS access) - correctly scoped as out of this agent's reach, not a gap |

All 25 tasks marked `✅ Complete` in `tasks.md`. No blocked/partial tasks.

---

## Spec-Anchored Acceptance Criteria

### P1: Full app in the user's language

| Criterion (WHEN X THEN Y) | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| I18N-01: pt-BR launch renders every listed UI surface in Brazilian Portuguese | Every listed surface's strings in pt-BR.lproj, genuinely Brazilian wording | `Sources/MCGuiUI/Resources/pt-BR.lproj/Localizable.strings:74` - `"topBar.menu.file" = "Arquivo"`; `:78` - `"panel.footer.fileCount" = "%1$d arquivos"` (sampled across TopBar/Panel/ProgressDialog/HelpWindow keys - all present); parity proven by `tests/MCGuiUITests/Localization/LocalizationCoverageTests.swift:65-74` (`keySetMatchesEnglish`, all 3 targets × pt-BR) | ✅ PASS |
| I18N-02: pt-PT uses genuine PT-PT vocabulary diverging from pt-BR (ficheiro not arquivo, etc.) | Real lexical divergence, not a pt-BR copy | `Sources/MCGuiUI/Resources/pt-PT.lproj/Localizable.strings:76` - `"topBar.menu.file" = "Ficheiro"` vs pt-BR's `"Arquivo"` at the same key; `help.subtitle` pt-PT "gestor de ficheiros" vs pt-BR "gerenciador de arquivos" - confirmed genuinely distinct, not duplicated text; parity via same `LocalizationCoverageTests` | ✅ PASS |
| I18N-03: English launch renders in English | en.lproj is the Base/development region, `CFBundleDevelopmentRegion=en` | `Package.swift:6` - `defaultLocalization: "en"`; `packaging/Info.plist:5-6` - `CFBundleDevelopmentRegion` = `en`; `Sources/MCGuiUI/Resources/en.lproj/Localizable.strings` (205 lines, base table all lookups fall back to) | ✅ PASS |
| I18N-04: Spanish launch renders in Spanish | es.lproj populated for every key | `Sources/MCGuiUI/Resources/es.lproj/Localizable.strings:2-5` - e.g. `"panel.footer.fileCount" = "%1$d archivos"`; parity via `LocalizationCoverageTests` (MCGuiUI/es, MCGuiApp/es, MCGuiMacOS/es all pass) | ✅ PASS |
| I18N-05: unsupported system language falls back to English | Apple Base-region negotiation, no custom fallback code | `Package.swift:6` `defaultLocalization: "en"` + `packaging/Info.plist:5-6` `CFBundleDevelopmentRegion=en` - this is the documented, correct mechanism (design.md Tech Decisions); no test directly simulates a 5th locale (relies on platform behavior, matches design's explicit decision not to reinvent it) | ⚠️ Spec-precision gap (mechanism verified by code inspection, not by an executed test - acceptable per design's explicit "rely on Apple's built-in behavior, no custom code to test" decision, but flagged since spec.md's Success Criteria calls this out as something to verify) |
| I18N-06: a single missing key falls back to English text, not blank/raw-key/crash | Apple's Base-region fallback per missing key | Same mechanism as I18N-05 (`Bundle.module`/`NSLocalizedString` search chain) - no direct test forces a genuinely missing key through production code and asserts the English fallback renders (the coverage test instead prevents missing keys from shipping at all, which is I18N-09, a stronger guarantee for translation completeness but not the same assertion as "a missing key resolves to English at runtime") | ⚠️ Spec-precision gap - no runtime test simulates the fallback path itself, though I18N-09's prevention makes the scenario unreachable by construction |
| I18N-07: locale-aware byte/date/decimal formatting | `ByteCountFormatter`/`DateFormatter` respect resolved `Locale` | `Sources/MCGuiUI/Views/ProgressDialog.swift:61,63` - `Text(ByteCountFormatter.string(fromByteCount:..., countStyle: .file))`; confirmed by code inspection that `ByteCountFormatter` resolves decimal separators/unit words from `Locale.current` internally (Foundation-documented behavior) - no unit test asserts the actual locale-specific output string | ⚠️ Spec-precision gap - relies on Foundation's documented behavior + code inspection, no executable test pins e.g. a Spanish "," decimal separator |
| I18N-08: packaged `.app`'s DMG carries all 4 languages, not just local build | Every resource-bearing target's bundle, with all 4 `.lproj`, present in `Contents/Resources` | Independently re-run (not trusting T25's own note): `find "artifacts/Midnight Commander GUI.app/Contents/Resources" -name "*.bundle" -type d` → `MCGui_MCGuiApp.bundle`, `MCGui_MCGuiMacOS.bundle`, `MCGui_MCGuiUI.bundle`; `find ... -name "*.lproj"` → all 3 bundles each carry `en/es/pt-br/pt-pt.lproj` (12 dirs total); `packaging/build-macos.sh` diff adds the copy step, `packaging/Info.plist:2-9` adds `CFBundleLocalizations` | ✅ PASS |

### P2: Missing translations are discoverable

| Criterion | Spec-defined outcome | `file:line` + assertion | Result |
| --- | --- | --- | --- |
| I18N-09: every UI string sourced from a centralized table; missing translation is discoverable, doesn't break the build | Key-set-diff test per target catches divergence; build still succeeds when a translation is merely absent (content gap, not compile error) | `tests/MCGuiUITests/Localization/LocalizationCoverageTests.swift:61-74` - `#expect(localizedKeys == englishKeys, ...)`, `@Test(arguments: targets, languages)` covers 3 targets × 3 non-en languages = 9 cases; independently re-verified as a REAL, non-stub test via the discrimination sensor (see below) - deleting one key from `pt-BR.lproj` made the test fail with the exact missing key named in the message | ✅ PASS |

**Status**: ✅ All ACs covered with direct evidence for I18N-01..04, I18N-08, I18N-09; ⚠️ 3 spec-precision gaps flagged for I18N-05/06/07 - each has correct code-level evidence (the mechanism is real and correctly wired) but no test executes the runtime fallback/formatting path itself. This matches design.md's explicit decision to rely on Apple's built-in behavior rather than custom code, and matches the Test Coverage Matrix's own scoping (no test type required for these three at the "SwiftUI View/Dialog string extraction" or "core" layers beyond what's covered) - not a functional defect, but the precise runtime outcome is not independently proven by an executed assertion.

---

## Discrimination Sensor

Isolated `git worktree add <scratch> HEAD` at `9acc2e7`. Baseline `git status --porcelain` on the real tree: empty (before and after). No `git stash` used.

| # | File:line | Description | Killed? |
| - | --- | --- | --- |
| 1 | `Sources/MCGuiMacOS/FileSystem/FileSystemServiceImpl.swift:29-37` | `.permissionDenied` case rewired to look up `"fileSystemError.alreadyExists"` instead of its own key | ✅ Killed - `FileSystemServiceErrorLocalizationTests.errorDescriptionWiring` failed: `"...already exists." != "Permission denied: ..."`. (Note: the 4 per-locale `permissionDenied` tests, which read the `.strings` table directly rather than through production wiring, did NOT fail - only the wiring-specific test caught it, confirming that test's value.) |
| 2 | `Sources/MCGuiUI/Resources/pt-BR.lproj/Localizable.strings:74` | Deleted the `buttonBar.label.help` key from pt-BR's copy only | ✅ Killed - `LocalizationCoverageTests.keySetMatchesEnglish` (MCGuiUI/pt-BR case) failed, message correctly named `missing ["buttonBar.label.help"]` |

**Sensor depth**: lightweight (2 mutations, default tier)
**Result**: 2/2 killed - PASS ✅
**Isolation verified**: `git worktree remove --force <scratch>`; real-tree `git status --porcelain` re-checked identical (empty) to the pre-sensor baseline.

---

## Code Quality

| Principle | Status |
| --- | --- |
| Minimum code | ✅ - each task touches exactly its named file(s) |
| Surgical changes | ✅ - `SyntaxHighlighter.swift` has zero diff across the whole range (I18N-13 verified via `git diff bebd5b5..9acc2e7 -- Sources/MCGuiUI/Views/SyntaxHighlighter.swift` = empty) |
| No scope creep | ✅ - Bookmarks/User Menu item data explicitly left untranslated with inline `I18N-12` comments (`BookmarksView.swift:129-130`, `UserMenuView.swift:205-208`); volume names, file paths, product name "Midnight Commander" all correctly left literal |
| Matches patterns | ✅ - key convention (namespaced dotted keys, e.g. `mkdirValidation.error.empty` in `MkdirDialogViewModel.swift:11-12`) matches AD-005 throughout sampled files (`TopBar.swift:57-66`, `MkdirDialogViewModel.swift`) |
| Spec-anchored outcome check | ✅ - see AC table; asserted values in `FileSystemServiceErrorLocalizationTests.swift` match spec-precise per-locale text exactly, not just "an assertion exists" |
| Per-layer Coverage Expectation met | ✅ - matches tasks.md's own Test Coverage Matrix: Localization core (unit, key parity) and `FileSystemServiceError` (unit, per-case×per-locale) both covered; SwiftUI view text intentionally untested, consistent with this project's established convention |
| Every test maps to a spec requirement | ✅ - `LocalizationCoverageTests` → I18N-09, `FileSystemServiceErrorLocalizationTests` → I18N-01..04 (error messages) |
| Documented guidelines followed | tasks.md's own Test Coverage Matrix (project convention: no direct unit tests for SwiftUI `View.body`) - followed |

**Minor finding (non-blocking)**: `Sources/MCGuiApp/Resources/*.lproj/Localizable.strings:2` and `Sources/MCGuiMacOS/Resources/*.lproj/Localizable.strings:2` still carry T1's `"app.placeholder"` key (translated into all 4 languages, e.g. `"marcador de posición"`), whose own comment says it is "Replaced by real UI keys starting in Phase 4" / "in T5" - it was never deleted after being superseded. Confirmed unreferenced anywhere in `Sources/` or `tests/` (grep). Harmless (present symmetrically in all 4 languages of both targets, so it doesn't trip `LocalizationCoverageTests`), but it's dead scaffolding left behind - a cleanup task, not a functional or spec gap.

---

## Edge Cases

- [x] I18N-10 (system-language-change-while-running): out of scope per spec - confirmed no live-reload code added (`git diff bebd5b5..9acc2e7` has zero matches for `NSSystemLocaleDidChange`/`localeDidChange`/locale-related `NotificationCenter`/`.onReceive` observers)
- [x] I18N-11 (translated text longer than English wraps/truncates, doesn't clip mid-character): qualitative - dialogs use `.frame(minWidth:)` (grows to fit) not fixed `.frame(width:)` (`CopyMoveDialog.swift:79`, `ConflictDialog.swift:41`, `MkdirDialog.swift:48`, `DeleteConfirmDialog.swift:51`, `SaveChangesDialog.swift:27`); `ButtonBar.swift:41-50` uses `.frame(maxWidth: .infinity)` with no `.lineLimit`/`.fixedSize`, so SwiftUI's default multi-line wrapping applies - concretely exercised by F6's label going from "RenMov" (en, 6 chars) to "Mover / Renomear"/"Mover / Renombrar" (pt-BR/es, 16-18 chars); not unit-tested (matches matrix - visual/layout concern, no test type required)
- [x] I18N-12 (user-authored content never translated): `BookmarksView.swift:129-130` (`bookmark.name`, inline `I18N-12` comment), `UserMenuView.swift:205-208` (`item.label`/`item.command`, inline `I18N-12` comment) - both confirmed untranslated, displayed verbatim
- [x] I18N-13 (SyntaxHighlighter keywords never translated): `git diff bebd5b5..9acc2e7 -- Sources/MCGuiUI/Views/SyntaxHighlighter.swift` is empty - file was never touched by this feature

---

## Gate Check

- **Gate command**: `swift build && swift test`
- **Result**: 318 passed, 0 failed, 0 skipped
- **Test count before feature** (re-derived, not taken from docs): 310 - independently measured by checking out `bebd5b5^` (`3af2e6c`, the commit immediately before this feature's first commit) into a scratch worktree and running `swift test`: `Test run with 310 tests in 40 suites passed`. **Correction to the task brief**: the pre-feature baseline is **310**, not 306 as stated in the verification brief - no literal "306" exists anywhere in `.specs/STATE.md`; "306+" appears only as a rough, non-authoritative estimate inside `tasks.md`'s T5 Done-when boilerplate. 310 is the actual, empirically-measured number and is what this report uses for the integrity check.
- **Test count after feature**: 318
- **Delta**: +8 new tests (9 `LocalizationCoverageTests` cases collapse into a smaller reported count due to parameterized `@Test` grouping in the runner's summary, plus 7 `FileSystemServiceErrorLocalizationTests` cases; net repository delta matches the sum of tasks' own per-commit confirmations: 310→311 (T4) →318 (T5 adds `FileSystemServiceErrorLocalizationTests`, T6 no new tests) - no test count decrease at any point in the range, no silent deletion)
- **Skipped tests**: none
- **Failures**: none

---

## Fix Plans

None required for PASS. Two spec-precision gaps (I18N-05/06 runtime fallback path, I18N-07 formatter output) and one minor dead-key cleanup are noted above as informational findings, not blockers - they don't represent incorrect behavior, only that the precise runtime outcome isn't independently pinned by an executed test, consistent with design.md's explicit choice to rely on unmodified Apple/Foundation behavior for those three ACs.

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| --- | --- | --- |
| I18N-01 | Implementing | ✅ Verified |
| I18N-02 | Implementing | ✅ Verified |
| I18N-03 | Implementing | ✅ Verified |
| I18N-04 | Implementing | ✅ Verified |
| I18N-05 | Pending | ✅ Verified (⚠️ spec-precision gap noted) |
| I18N-06 | Pending | ✅ Verified (⚠️ spec-precision gap noted) |
| I18N-07 | Pending | ✅ Verified (⚠️ spec-precision gap noted) |
| I18N-08 | Implementing | ✅ Verified |
| I18N-09 | Implementing | ✅ Verified |
| I18N-10 | Pending | ✅ Verified |
| I18N-11 | Pending | ✅ Verified |
| I18N-12 | Pending | ✅ Verified |
| I18N-13 | Pending | ✅ Verified |

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 10/13 ACs matched spec outcome directly; 3 spec-precision gaps flagged (I18N-05, I18N-06, I18N-07 - correct mechanism, no executed runtime-path test)
**Sensor**: 2/2 mutations killed
**Gate**: 318 passed, 0 failed (baseline was 310, re-measured independently - not 306 as stated in the task brief)

**What works**: All 25 tasks complete and gated. Genuine pt-BR/pt-PT lexical divergence confirmed by direct file inspection. `FileSystemServiceError` localization exact-text-per-locale proven and mutation-tested. `LocalizationCoverageTests` proven to be a real, discriminating test (not a stub) via the sensor. Packaging independently re-verified: the actual built DMG's `.app` carries all 3 resource bundles × 4 languages. I18N-10/12/13 edge cases confirmed via diff inspection (no live-reload code, no user-data translation, `SyntaxHighlighter.swift` untouched). I18N-11 qualitatively addressed via `minWidth`/unconstrained-wrap layout, exercised by a real length disparity (F6 label).

**Issues found**: None blocking. One dead placeholder key (`app.placeholder`) left over from T1 in `MCGuiApp`/`MCGuiMacOS` tables, translated into all 4 languages but never referenced - harmless, worth deleting in a future cleanup pass.

**Next steps**: None required to close this feature. Optional/non-blocking: remove the `app.placeholder` keys; if desired, add a runtime test that forces a genuinely missing key through `Bundle.module` and asserts the English fallback text (would close the I18N-06 spec-precision gap) and/or a locale-parameterized `ByteCountFormatter` test (I18N-07). T25's remaining checkbox (user's own visual System-Language walkthrough of the installed DMG) is explicitly owned by the user per spec.md's Independent Test - not part of this Verifier's scope.
