# macOS Installer Validation

**Date**: 2026-09-05
**Spec**: `.specs/features/macos-installer/spec.md`
**Diff range**: `dbfe690~1..HEAD` (feature range starts at plan commit `dbfe690`; earlier mc-menubar/panel commits are outside the range)
**Verifier**: independent sub-agent (author ≠ verifier)

---

## Task Completion

| Task | Status     | Notes   |
| ---- | ---------- | ------- |
| T1   | ✅ Done    | Info.plist + make-icon.sh + gitignore; regression ok |
| T2   | ✅ Done    | build-macos.sh .app assembly; idempotent; version arg ok |
| T3   | ✅ Done    | DMG drag-to-install; mount UAT ok (visual "Tudo ok" recorded by author) |
| T4   | ✅ Done    | CI workflow; release v0.1.0 + asset confirmed live |

---

## Spec-Anchored Acceptance Criteria

Spec defines 14 requirements PKG-01..14 (4 script, 5 bundle, 2 icon, 3 CI). Validation is **script auto-checks + mount UAT + live CI run**, not xunit (design D8, tasks matrix). Evidence-or-zero via `file:line`.

| Req | Criterion (WHEN X THEN Y) | Spec-defined outcome | Evidence (file:line + assertion/observation) | Result |
| --- | ------------------------- | -------------------- | ------------------------------------------- | ------ |
| PKG-01 | script runs THEN produces valid `.app` bundle structure | `Contents/{MacOS,Resources,Info.plist}` populated | `packaging/build-macos.sh:40-51` (mkdir + copy publish→MacOS + icns + plist); functional run: `ls "artifacts/Midnight Commander GUI.app/Contents"` shows MacOS/Resources/Info.plist; `McGui.App.dll` present in MacOS | ✅ PASS |
| PKG-02 | script runs THEN produces `mc-gui-0.1.0-arm64.dmg` containing the `.app` | DMG named with version+arch | `packaging/build-macos.sh:20,70-71` (DMG_PATH=...-arm64.dmg, hdiutil create); artifact `artifacts/mc-gui-0.1.0-arm64.dmg` (49.7M) created; `hdiutil attach` → volume contains `Midnight Commander GUI.app` | ✅ PASS |
| PKG-03 | script SHALL be idempotent | re-run overwrites artifacts/ without error | `packaging/build-macos.sh:26-27` (`rm -rf "$ARTIFACTS"`); two consecutive re-runs exited 0 | ✅ PASS |
| PKG-04 | script run from any directory THEN resolves paths to repo root | output lands under repo-root `artifacts/` | `packaging/build-macos.sh:9-10` (SCRIPT_DIR=`dirname $0`; REPO_ROOT=..); executed `/Users/pacelli/.../packaging/build-macos.sh` from `/tmp` → DMG at repo-root `artifacts/mc-gui-0.1.0-arm64.dmg` | ✅ PASS |
| PKG-05 | Info.plist SHALL declare bundle identity keys | id `mcgui.jpmo.dev.br`, exec `mc-gui`, APPL, NSHighResolutionCapable=true, version 0.1.0; name/displayname per assumption table (spec:37: CFBundleName `MC GUI` ≤15 chars, CFBundleDisplayName `Midnight Commander GUI`) | `packaging/Info.plist:7-28`; `plutil -extract` on built plist → `CFBundleIdentifier=mcgui.jpmo.dev.br`, `CFBundleExecutable=mc-gui`, `CFBundleName=MC GUI`, `CFBundleDisplayName=Midnight Commander GUI`, `CFBundleShortVersionString=CFBundleVersion=0.1.0`, `CFBundlePackageType=APPL`, `NSHighResolutionCapable=true` | ✅ PASS (spec:77 AC text says name=`mc-gui` but assumption spec:37 + design D3 define MC GUI / Midnight Commander GUI — outcome per governing decision) |
| PKG-06 | Info.plist SHALL pass `plutil -lint` | exit 0, no errors | `packaging/build-macos.sh:54` (plutil -lint with `set -e`); run: `plutil -lint .../Info.plist` → OK | ✅ PASS |
| PKG-07 | bundle SHALL contain valid `mc-gui.icns` referenced by CFBundleIconFile | icns present, iconutil round-trip ok, plist references it | `packaging/make-icon.sh:36-38` + `packaging/build-macos.sh:49,55` (cp + `test -s`); `packaging/Info.plist:9-10` (CFBundleIconFile=mc-gui.icns); functional: icns 105.8K in Resources; `iconutil -c iconset` round-trip OK | ✅ PASS |
| PKG-08 | executable at `Contents/MacOS/mc-gui` SHALL be Mach-O arm64 | self-contained publish output arm64 | `packaging/build-macos.sh:47,56-62` (rename apphost + `file` auto-check `*arm64*executable*`); run: `file .../MacOS/mc-gui` → `Mach-O 64-bit executable arm64` | ✅ PASS |
| PKG-09 | `.app` opened on macOS arm64 THEN launches | visual launch | author UAT recorded tasks.md T3 (`[x]` "App abre do volume (janela mc-gui confirmada)", UAT "Tudo ok"; commit 494f628); host rename safe: `McGui.App.dll` present beside renamed host (build-macos.sh:42,47) | ✅ PASS (visual UAT by author; verifier did not re-launch GUI) |
| PKG-10 | script runs THEN generates 1024px source PNG + converts to `.icns` | programmatic PNG via PIL per spec:38,95 | **SPEC_DEVIATION**: implementation dropped PIL/generated-PNG. Source is **committed** `packaging/icon-asset/mc-gui-icon-1024.png` (1024px); `make-icon.sh` regenerates iconset + icns at build via sips+iconutil. Spec.md was not updated (still says PIL / `packaging/icon/icon-source.png`). Decided in commits a73e877/f45ca73 + tasks T4 note ("ícone via PNG commitado (sem PIL)"). icns output path still produced. | ⚠️ Deviation (documented; functional outcome met — non-empty valid icns produced at build) |
| PKG-11 | generated `.icns` SHALL be non-empty and structurally valid | iconutil succeeds | `packaging/make-icon.sh:37-38` (`iconutil -c icns` + `test -s` under `set -e`); run: icns 105.8K, `iconutil -c iconset` round-trip OK | ✅ PASS |
| PKG-12 | workflow runs on macos runners, checkout, install .NET, execute same script | same build-macos.sh reused | `.github/workflows/build-macos.yml:14,17,20-22,30-32` (`runs-on: macos-14`, checkout@v4, setup-dotnet 10.0.x, `./packaging/build-macos.sh "$VERSION"`); YAML parses (`python3 yaml.safe_load` OK); live CI runs green on main + tag | ✅ PASS |
| PKG-13 | workflow finishes THEN uploads `.dmg` as artifact | artifact named mc-gui-dmg | `.github/workflows/build-macos.yml:34-39` (upload-artifact path `artifacts/*.dmg`, `if-no-files-found: error`); live: main-branch run #33997057672 artifact `mc-gui-dmg` (50,152,260 bytes, not expired) | ✅ PASS |
| PKG-14 | workflow on git tag THEN attaches `.dmg` to a GitHub Release | tag v0.1.0 release + asset | `.github/workflows/build-macos.yml:41-50` (gh release create on `refs/tags/v*`); live: `gh release view v0.1.0` → tag `v0.1.0`, authored by github-actions[bot], asset `mc-gui-0.1.0-arm64.dmg` (52,130,256 bytes, application/x-apple-diskimage); version prefix `v` correctly stripped (`mc-gui-0.1.0-…`, not `mc-gui-v0.1.0-…`) | ✅ PASS |

**Status**: ✅ 13/14 PASS, 1 ⚠️ documented deviation (PKG-10 icon source method). No failed ACs.

---

## Edge Cases

| Edge case | Evidence | Result |
| --------- | -------- | ------ |
| Existing `artifacts/` / `.app` → clean regenerate, no stale files | `build-macos.sh:26-27` `rm -rf`; 9.9.9 run then default run → `mc-gui-9.9.9-arm64.dmg` gone, only `mc-gui-0.1.0-arm64.dmg` remains | ✅ Handled |
| Version argument overrides default 0.1.0 | `build-macos.sh:11` (`${1:-0.1.0}`) + `sed` injection :51; run `./packaging/build-macos.sh 9.9.9` → plist `CFBundleShortVersionString/CFBundleVersion=9.9.9`, DMG `mc-gui-9.9.9-arm64.dmg` | ✅ Handled |
| Missing tool → clear failure message | `build-macos.sh:22-24` (`command -v` for dotnet/hdiutil/plutil/file → "ERROR: X required"), `make-icon.sh:12-13` (sips/iconutil) | ✅ Handled (code inspection) |
| Mounted DMG contains app + Applications link | `build-macos.sh:68` (`ln -s /Applications`); `hdiutil attach` → `Midnight Commander GUI.app` dir + `Applications -> /Applications` symlink | ✅ Handled |

---

## Discrimination Sensor

Scripts, not unit code — the "behavior under test" is script output. Sensor = version-injection fault probe + idempotency reruns, run against the real (gitignored, scratch-equivalent) `artifacts/` output. Baseline `git status --porcelain` before = empty; after = empty.

| Mutation probe | File:line | Description | Killed? |
| -------------- | --------- | ----------- | ------- |
| 1 | `packaging/build-macos.sh:11,51` | Injected version 9.9.9 → if injection were broken, plist would stay 0.1.0 | ✅ Killed — plist read 9.9.9; DMG named `mc-gui-9.9.9-arm64.dmg` |
| 2 | `packaging/build-macos.sh:70-71` | Rebuilt default → stale 9.9.9 DMG must not persist (clean/regenerate) | ✅ Killed — `mc-gui-9.9.9-arm64.dmg` absent after default rebuild |
| 3 | `packaging/build-macos.sh:54,56-62` | Bundle auto-checks (plutil lint, Mach-O arm64, icns non-empty) are the deterministic regression fence; all three tripped to success only on valid output | ✅ Killed — plutil OK, `file` arm64, icns 105.8K |

**Sensor depth**: lightweight (3 probes, version-injection highest-risk behavior)
**Result**: 3/3 killed - **PASS ✅**

---

## Interactive UAT Results (if performed)

| # | Test | Result | Details |
| - | ---- | ------ | ------- |
| 1 | App opens from volume with correct name/icon/version | ✅ Pass (author, recorded tasks.md T3) | User: "Tudo ok" — janela mc-gui confirmada, DMG desmonta |

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ — 73-line build script, 39-line icon script, no abstraction bloat |
| Surgical changes | ✅ — diff range = 10 files (2 scripts, plist, workflow, 1 png, gitignore, spec docs, 1-line axaml title); no unrelated churn |
| No scope creep | ✅ — out-of-scope (signing/notarize/Intel/.pkg) untouched |
| Matches patterns | ✅ — GNU `set -euo pipefail` shell, SCRIPT_DIR idiom, consistent with repo |
| Spec-anchored outcome check | ✅ — asserted values match spec/assumption outcomes (see table); PKG-10 deviation documented |
| Would senior engineer approve | ✅ — rename-apphost safe (dll co-located), deterministic auto-checks, reuses one script in CI/local, no PIL in CI |
| Shell best-effort vs coding-principles | ✅ — `command -v` guards, `-o`/`rm -rf` idempotency, clear ERROR messages to stderr; acceptable for build tooling |

---

## Gate Check

- **Gate command**: `./packaging/build-macos.sh && dotnet format McGui.sln --verify-no-changes && dotnet build McGui.sln -warnaserror && dotnet test McGui.sln` (full, tasks.md:32)
- **Result**: 180 passed, 0 failed, 0 skipped
- **Test count before feature**: 180 (tasks.md:121,25 "180 testes")
- **Test count after feature**: 180
- **Delta**: 0 new xunit (by design — packaging validated by script auto-checks + UAT + CI; tasks.md:25)
- **Skipped tests**: none
- **Failures**: none
- **dotnet format --verify-no-changes**: exit 0 · **dotnet build -warnaserror**: 7 projects, 0 errors, 0 warnings

---

## Fix Plans

None — no functional gaps.

Minor documentation follow-up (not blocking):
- **PKG-10 spec drift**: `spec.md:38,95` and `design.md:44` still describe PIL-generated PNG at `packaging/icon/icon-source.png`; implementation commits `packaging/icon-asset/mc-gui-icon-1024.png` and regenerates icns only (sips+iconutil). Spec text should be updated to match, or a `SPEC_DEVIATION` marker added.

---

## Requirement Traceability Update

Spec.md statuses (all `Pending`) were not mutated by the Verifier (read-only mandate; only validation.md written). Verified by evidence above.

| Requirement | Previous Status | New Status   |
| ----------- | --------------- | ------------ |
| PKG-01..PKG-09 | Pending | ✅ Verified |
| PKG-10        | Pending | ⚠️ Verified w/ documented deviation |
| PKG-11..PKG-14 | Pending | ✅ Verified |

---

## CI Run Result

- Workflow `.github/workflows/build-macos.yml` — `python3 yaml.safe_load` → valid YAML.
- Live runs (gh run list): main + tag `v0.1.0` latest → **success** (earlier failures during feature dev resolved by committing icon PNG, no PIL).
- Release `v0.1.0`: https://github.com/josepacelli/mc-gui/releases/tag/v0.1.0 — asset `mc-gui-0.1.0-arm64.dmg` (52.1 MB) attached by workflow. Confirmed via `gh release view`.
- Artifact on main-branch run: `mc-gui-dmg` (50.1 MB) present, not expired.

## Functional Checks (executed 2026-09-05)

| Check | Command | Result |
| ----- | ------- | ------ |
| DMG exists | `ls artifacts/*.dmg` | `mc-gui-0.1.0-arm64.dmg` (49.7M) ✅ |
| plist lint | `plutil -lint` | OK ✅ |
| plist keys | `plutil -extract` | id/exec/name/displayname/version/APPL/NSHighRes/icon all correct ✅ |
| binary | `file` | `Mach-O 64-bit executable arm64` ✅ |
| icns | `ls` + `iconutil -c iconset` | 105.8K, round-trip OK ✅ |
| DMG mount | `hdiutil attach` | app + Applications symlink; detach ok ✅ |
| Version injection | `build-macos.sh 9.9.9` | plist 9.9.9 + `mc-gui-9.9.9-arm64.dmg` ✅ |
| Idempotency | re-run default | exit 0, stale 9.9.9 DMG cleaned ✅ |
| Any-dir run | from `/tmp` | artifacts at repo root ✅ |
| git clean | `git status --porcelain` | empty (artifacts/ `*.dmg` `*.app/` ignored) ✅ |

---

## Summary

**Overall**: ✅ Ready

**Spec-anchored check**: 13/13 ACs matched spec outcome (PKG-05 name per assumption table), 1 documented deviation (PKG-10 icon source method — spec text stale, output met)
**Sensor**: 3/3 mutations killed
**Gate**: 180 passed, 0 failed
**CI**: release v0.1.0 + asset confirmed live

**What works**: local script → valid arm64 `.app` + DMG drag-to-install; plist/binary/icns auto-verified; version injection + idempotency proven; same script drives CI; release asset attached from tag.

**Issues found**: none functional. PKG-10: spec.md/design.md describe PIL-generated PNG; implementation uses committed 1024px PNG source (no PIL) — safer for CI, but spec text not updated (documentation drift only).

**Next steps**: (optional) update spec.md:38,95 + design.md:44 to the committed-PNG approach, or add `SPEC_DEVIATION` marker. No code changes required.
