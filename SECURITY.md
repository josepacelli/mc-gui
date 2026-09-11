# Security Policy

## Supported Versions

Only the latest release is supported. mc-gui is pre-1.0 and moves fast; please
update to the latest tag/DMG from [Releases](https://github.com/josepacelli/mc-gui/releases/latest)
before reporting an issue.

## Reporting a Vulnerability

Please report security issues privately, not as a public GitHub issue:

- Preferred: open a [GitHub Security Advisory](https://github.com/josepacelli/mc-gui/security/advisories/new)
  for this repository.
- Alternative: email josepacelli@gmail.com with a description and reproduction
  steps.

You should get an acknowledgement within a few days. This is a single-maintainer
open-source project (no bug bounty), but real reports will be fixed and credited
in the release notes unless you ask to stay anonymous.

## Security Model

mc-gui is a local, single-user macOS file manager. There is no account system,
no backend, and no telemetry — it does not phone home. Its threat model is
mostly local: the risks are about what the app does to files on disk and what
it runs as a process, not about network attackers.

A few things worth knowing:

- **Unsigned build.** Releases are unsigned development builds; installing
  requires bypassing Gatekeeper (right-click → Open). Only download the DMG
  from the official [Releases](https://github.com/josepacelli/mc-gui/releases/latest)
  page or build it yourself from source.
- **Trash, not delete.** File removal (F8) goes through the system Trash
  (`TrashService`), not a permanent unlink, so accidental/malicious deletions
  via the UI are recoverable the same way Finder deletions are.
- **User Menu (F2) runs real shell commands.** This feature lets you define
  your own commands (`%f`/`%d`/`%D` macros expanding to the current
  file/directory) and run them via `/bin/sh -c`
  (`Sources/MCGuiMacOS/UserMenu/UserMenuRunner.swift`). These commands run with
  your own user privileges — there's no sandboxing or privilege boundary
  around them, by design, the same as the original Midnight Commander's User
  Menu. Treat every entry you add here as a shell script you trust.
  `%f`/`%d`/`%D` expansion POSIX-single-quotes the path (embedded `'`
  escaped as `'\''`), so shell metacharacters in a file or directory name
  (`` ` ``, `$`, `"`) cannot break out of the substitution or trigger command
  substitution.

## Scope

In scope: the mc-gui app itself (`Sources/`, packaging scripts, release
workflow). Out of scope: the upstream Midnight Commander project (not
affiliated, no shared code) and third-party dependencies (none currently
vendored).
