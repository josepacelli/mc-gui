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
- **Real copy/move** (F5/F6) — per-file progress with transfer speed (B/s, MB/s, GB/s) and
  ETA, a working Cancel mid-copy, and an explicit *Background* option that runs silently,
  like the original. Progress runs in an independent, non-modal window — both panels stay
  usable during a transfer.
- **Drag-and-drop copy between panels** — drag a file or folder (or the current marked
  selection) from one panel and drop it on the other; the same copy confirmation dialog as
  F5 always appears first, so nothing copies without you seeing source/destination.
- **Right-click context menu** — Open, Select/Deselect, Zip, Edit, Delete, and Show Info
  (size, permissions, dates; folder size computed recursively in the background) on any
  file or folder, without leaving the mouse.
- **Go to Folder** — double-click the path bar (or its button) to jump straight to a
  directory: type a path or pick it from a live, lazy-loaded directory tree.
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

To produce the same release build and installer DMG published under
[Releases](https://github.com/josepacelli/mc-gui/releases) (built locally, see
[Releases](#releases) below):

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

Releases are built and published locally, not by CI (`build-macos.yml` is disabled — a bad
build once slipped through it and produced a DMG Gatekeeper reported as "damaged"; building
and checking the DMG by hand before publishing catches that first):

```bash
./packaging/build-macos.sh 1.0.4
# sanity-check the DMG isn't going to show "damaged" before shipping it:
xattr -w com.apple.quarantine "0081;00000000;Safari;" "artifacts/Midnight Commander GUI.app"
spctl -a -vv "artifacts/Midnight Commander GUI.app"   # expect: rejected (unsigned), never a resources/corruption error

git tag -a v1.0.4 -m "v1.0.4"
git push origin v1.0.4
gh release create v1.0.4 artifacts/mc-gui-1.0.4-arm64.dmg --title "mc-gui v1.0.4" --notes "…"
```

## License

[GPL-3.0](LICENSE) — open source, free to use including commercially; distributed modified
versions must remain open source under the same license.
