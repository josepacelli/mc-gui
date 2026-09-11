# Midnight Commander for macOS

A free, open-source, **native macOS rewrite** of [Midnight Commander](https://midnight-commander.org/)
in Swift/SwiftUI: the same classic dual-pane layout, the same F-key shortcuts, the same
keyboard-driven workflow — as a real `.app` with native windows and a native menu bar,
instead of a terminal program. No Homebrew, no `mc` install, no terminal window required.

**Not affiliated with the GNU Midnight Commander project.** Independent, from-scratch
reimplementation — no ported C code — that reproduces its layout and workflow.

Landing page: **[mc.jpmo.dev.br](https://mc.jpmo.dev.br)**

## Features

- **Classic dual-pane layout** — `Left | File | Command | Options | Right` menu row, two
  file panels, and the numbered `F1`-`F10` button row at the bottom.
- **Built-in viewer & editor** (F3/F4) — native text/hex viewer, a real text editor with
  heuristic syntax highlighting, no external app needed.
- **Real copy/move** (F5/F6) — per-file progress, byte counts, a working Cancel mid-copy,
  and an explicit *Background* option that runs silently, like the original. Progress runs
  in an independent, non-modal window — both panels stay usable during a transfer.
- **Bookmarks & User Menu** (F2) — save frequent directories, and define your own shell
  commands with `%f`/`%d`/`%D` macros, run against the current file or panel.
- **Back/forward history, sort, hidden files** — per-panel, all reachable from the
  keyboard, mouse, or the native menu bar.
- **4 languages, automatic** — Portuguese (Brazil), Portuguese (Portugal), English and
  Spanish, following the Mac's System Language. No in-app picker.
- **No account, no telemetry** — nothing phoned home.

## Requirements

- macOS 14.0+
- Apple Silicon (arm64)

## Install

Download the latest DMG from [Releases](https://github.com/josepacelli/mc-gui/releases/latest),
drag the app to `/Applications`.

It's an **unsigned development build** — on first launch, right-click the app and choose
**Open** (instead of double-clicking) to get past Gatekeeper's warning.

## Build from source

Requires Xcode 15+ / Swift 5.9+.

```bash
git clone https://github.com/josepacelli/mc-gui.git
cd mc-gui
swift build            # debug build
swift test              # run the test suite
swift run MCGuiApp       # run the app directly
```

To produce the same signed-DMG-free release build and installer the GitHub Actions
workflow (`.github/workflows/build-macos.yml`) publishes:

```bash
./packaging/build-macos.sh 0.1.0
```

This builds in release mode, assembles `Midnight Commander GUI.app` (bundling every
target's resources, including all 4 languages' `.lproj` string tables), and produces a
drag-to-Applications DMG under `artifacts/`.

## Project structure

Single Swift Package (`MCGui`) with 4 targets, following a Clean Architecture split:

| Target | Role |
| --- | --- |
| `MCGuiCore` | Models and protocols, no OS dependency |
| `MCGuiUI` | SwiftUI views/view models, platform-agnostic |
| `MCGuiMacOS` | Concrete macOS implementations (filesystem, viewer/editor, bookmarks, user menu) |
| `MCGuiApp` | Executable entry point, wires everything together, owns window management |

`MCGuiUI` never imports `MCGuiMacOS` — cross-target bridging happens via closure-based
`*Actions` structs constructed in `MCGuiApp`, keeping the UI layer testable without a real
filesystem.

## Localization

UI strings live in classic `.strings` tables, one `Resources/<lang>.lproj/Localizable.strings`
per language per target. A dedicated test suite (`LocalizationCoverageTests`) asserts every
target's pt-BR/pt-PT/es table has exactly the same keys as its English base table, so a
missing translation fails `swift test` instead of shipping silently.

## Contributing

Issues and pull requests welcome.

- **Bug reports / feature requests**: use the issue templates — they ask for exactly what's
  needed to act on a report (expected vs. actual behavior, macOS version, suspect file for
  bugs; problem/proposal for feature requests). Usage questions and open-ended ideas go to
  [Discussions](https://github.com/josepacelli/mc-gui/discussions) instead of an issue.
- **Pull requests**: follow the PR template's test plan — `swift build`/`swift test` must
  pass, and a changed packaging script needs a real `./packaging/build-macos.sh` run.
  Every push and PR against `main` also runs automatically in CI
  ([`tests.yml`](.github/workflows/tests.yml): build + full test suite).
  [`codeql.yml`](.github/workflows/codeql.yml) (static analysis) exists but is currently
  disabled (`workflow_dispatch` only).

## Releases

Tagging a commit `vX.Y.Z` and pushing the tag triggers
[`build-macos.yml`](.github/workflows/build-macos.yml): it builds the release DMG and
attaches it to a new GitHub Release for that tag automatically. The same workflow also
runs on every push to `main` (without creating a release) as a build-health check.

```bash
git tag v1.0.0
git push origin v1.0.0
```

## License

[GPL-3.0](LICENSE) — open source, free to use including commercially; distributed modified
versions must remain open source under the same license.
