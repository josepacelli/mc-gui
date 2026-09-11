# Windows / Linux Support Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje roda apenas no macOS (via `McGui.Infrastructure.macOS`). O objetivo declarado do projeto é ser um clone multiplataforma do Midnight Commander (Windows/macOS/Linux). Esta feature entrega o suporte a Windows e Linux: projetos de infraestrutura `McGui.Infrastructure.Windows` e `McGui.Infrastructure.Linux`, implementação de `IFileSystemService`, `ITrashService`, `IPathHistoryStore`, `ICredentialStore`, `INotificationService` para cada plataforma, instaladores nativos (MSIX/Windows, AppImage/Flatpak/DEB/RPM Linux), e validação de paridade funcional cross-platform.

## Goals

- [ ] Projeto `McGui.Infrastructure.Windows` implementando: `WindowsFileSystemService` (File.Copy/Move/Delete/GetUnixFileMode via P/Invoke ou .NET 8+ Unix APIs), `WindowsTrashService` (SHFileOperation `FO_MOVE` to Recycle Bin), `WindowsPathHistoryStore` (JSON em `%APPDATA%\mc-gui`), `WindowsCredentialStore` (Credential Manager `CredWrite`/`CredRead`), `WindowsNotificationService` (Windows 10+ Toast `Windows.UI.Notifications`).
- [ ] Projeto `McGui.Infrastructure.Linux` implementando: `LinuxFileSystemService` (File APIs nativas .NET 8+), `LinuxTrashService` (FreeDesktop Trash Spec `~/.local/share/Trash`), `LinuxPathHistoryStore` (JSON em `~/.config/mc-gui`), `LinuxCredentialStore` (libsecret via `SecretService` D-Bus), `LinuxNotificationService` (libnotify `notify-send`).
- [ ] CompositionRoot atualizado para registrar infraestrutura correta via `OperatingSystem.IsWindows()` / `IsLinux()` / `IsMacOS()`.
- [ ] Instalador Windows: MSIX package (`.msix`/`.appx`) via `wapproj` ou MSIX Packaging Tool; assinatura opcional; auto-update via AppInstaller; start menu entry; file associations (opcional).
- [ ] Instalador Linux: AppImage (`.AppImage` via `linuxdeploy` + `appimagetool`); Flatpak manifest (`.flatpak`); DEB/RPM packages via `dotnet publish -r linux-x64 --self-contained` + `fpm` ou `cargo-deb`; `.desktop` entry; ícone hicolor; MIME types.
- [ ] Validação de paridade: suite de testes roda nas 3 plataformas (GitHub Actions matrix: macOS, Ubuntu, Windows); testes de integração `IFileSystemService`, `ITrashService`, `IPathHistoryStore`, `ICredentialStore`, `INotificationService` passam em todas.
- [ ] Ajustes de UI cross-platform: atalhos de teclado (Win/Linux usam `Ctrl` em vez de `Cmd` onde apropriado; `Meta` key mapping); paths (`\` vs `/`); line endings; case sensitivity; file dialogs nativos vs Avalonia.
- [ ] CI/CD: GitHub Actions workflows para build/test/release nas 3 plataformas; artifacts: `.dmg` (macOS), `.msix` (Windows), `.AppImage`/`.flatpak`/`.deb`/`.rpm` (Linux).

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Windows ARM64 / Linux ARM64 | x64 prioritário; ARM64 depois (Apple Silicon já coberto no macOS) |
| Windows 7/8.1 support | .NET 8+ requer Windows 10+; Win7 EOL |
| Linux distro-specific packaging (Snap, Nix, Arch AUR) | AppImage/Flatpak/DEB/RPM cobrem 95%; outros depois |
| Portable/standalone zip (sem instalador) | Nice-to-have; instaladores são padrão |
| Auto-update framework (Squirrel, etc.) | MSIX/Flatpak/AppImage têm update built-in; Windows MSIX usa AppInstaller |
| Windows Store / Mac App Store / Flathub publishing | Processo manual de review; CI gera artifacts, publish manual |
| Wayland-specific fixes (Linux) | Avalonia abstrai; testar no CI Ubuntu (Wayland default) |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| .NET RID | `win-x64`, `linux-x64`, `osx-arm64` (macOS já feito) | Alvos principais | n |
| UI framework | Avalonia 11+ (já usado) — cross-platform nativo | Já decidido | n |
| FileSystemService Windows | `File.GetUnixFileMode`/`SetUnixFileMode` .NET 8+ funciona no Windows (NTFS) | .NET 8+ unifica APIs | n |
| Trash Windows | `SHFileOperation` com `FO_MOVE` + `FOF_ALLOWUNDO` + `FOF_NOCONFIRMATION` via P/Invoke `shell32.dll` | Padrão Windows | n |
| Trash Linux | FreeDesktop Trash Spec: `~/.local/share/Trash/{files,info}` + `.trashinfo` files | Padrão GNOME/KDE/XFCE | n |
| Credential Store Windows | `CredWrite`/`CredRead`/`CredDelete` (`advapi32.dll`) com `CRED_TYPE_GENERIC` | Windows Credential Manager | n |
| Credential Store Linux | `SecretService` D-Bus (`org.freedesktop.secrets`) via `libsecret` ou `D-Bus` client .NET | GNOME Keyring / KWallet | n |
| Notifications Windows | `Windows.UI.Notifications.ToastNotificationManager` (WinRT) via `Microsoft.Windows.SDK.Contracts` | Modern Windows | n |
| Notifications Linux | `notify-send` (libnotify) via `Process.Start` ou `DBus` | Universal Linux | n |
| Installer Windows | MSIX (`.msix`) — moderno, assinado, auto-update, sandbox opcional | Substituto do MSI | n |
| Installer Linux | AppImage (universal) + Flatpak (sandbox) + DEB/RPM (distro nativo) | Cobertura máxima | n |
| CI Matrix | GitHub Actions: `macos-14` (arm64), `ubuntu-latest` (x64), `windows-latest` (x64) | Runners padrão GH | n |
| Testes cross-platform | `dotnet test` roda em todas; `OperatingSystem.IsX()` guards nos testes de infra | Já praticado | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Infraestrutura Windows ⭐ MVP

**User Story**: Como usuário Windows, quero rodar mc-gui nativamente no Windows 10/11 com todas as funcionalidades (sistema de arquivos, lixeira, histórico, credenciais, notificações), para usar o gerenciador no meu SO.

**Why P1**: Multiplataforma é objetivo declarado; Windows é maior base de usuários desktop.

**Acceptance Criteria**:

1. THE `McGui.Infrastructure.Windows` project SHALL compile and pass all interface contract tests (`IFileSystemService`, `ITrashService`, `IPathHistoryStore`, `ICredentialStore`, `INotificationService`).
2. `WindowsFileSystemService` SHALL support: `ListDirectory`, `CreateDirectory`, `CopyAsync`, `MoveAsync` with `CopyMoveOptions` (PreserveAttributes via `File.SetUnixFileMode` on NTFS, FollowSymlinks via `File.CreateSymbolicLink`).
3. `WindowsTrashService` SHALL move files to Recycle Bin (not permanent delete) by default; Shift+Delete bypasses; `SHFileOperation` with `FOF_ALLOWUNDO`.
4. `WindowsCredentialStore` SHALL store/retrieve FTP/SFTP credentials in Windows Credential Manager; survives reboot.
5. `WindowsNotificationService` SHALL show toast notifications for background job completion, copy/move done, errors.
6. ALL existing tests (236+) SHALL pass on Windows runner in CI.

**Independent Test**: Rodar mc-gui no Windows 11 → painéis listam arquivos; F5 copia com progresso; F8 move para Lixeira; Ctrl+\ hotlist persiste; credenciais FTP salvas no Credential Manager; notificação toast aparece.

---

### P1: Infraestrutura Linux ⭐ MVP

**User Story**: Como usuário Linux, quero rodar mc-gui nativamente no Ubuntu/Fedora/Arch/etc. com integração completa (lixera FreeDesktop, keyring, notificações libnotify).

**Why P1**: Linux é base histórica do MC; usuários esperam integração desktop nativa.

**Acceptance Criteria**:

1. THE `McGui.Infrastructure.Linux` project SHALL compile and pass all interface contract tests.
2. `LinuxFileSystemService` SHALL use .NET 8+ Unix APIs (`File.GetUnixFileMode`, `File.SetUnixFileMode`, `File.CreateSymbolicLink`).
3. `LinuxTrashService` SHALL implement FreeDesktop Trash Spec: move to `~/.local/share/Trash/files/`, create `.trashinfo` in `~/.local/share/Trash/info/` with original path and deletion date; handles name collisions (renames).
4. `LinuxCredentialStore` SHALL use `SecretService` D-Bus (`org.freedesktop.secrets`) via `libsecret` or `DBus` client; store/retrieve FTP/SFTP credentials in GNOME Keyring / KWallet.
5. `LinuxNotificationService` SHALL call `notify-send` via `Process.Start` for toast notifications; supports urgency, icon, category.
4. ALL existing tests (236+) SHALL pass on Ubuntu runner in CI.

**Independent Test**: Rodar mc-gui no Ubuntu 24.04 → painéis funcionam; F8 usa lixeira (aparece em `~/.local/share/Trash`); credenciais salvas no keyring (Seahorse mostra); `notify-send` toast aparece.

---

### P1: Instaladores nativos ⭐ MVP

**User Story**: Como usuário final, quero baixar e instalar mc-gui via instalador nativo do meu SO (MSIX no Windows, AppImage/Flatpak/DEB no Linux), para instalar como qualquer app.

**Why P1**: Distribuição profissional; `dotnet run` não é experiência de usuário final.

**Acceptance Criteria**:

1. WINDOWS: `packaging/build-windows.ps1` (ou MSIX project) SHALL produce `mc-gui-<version>-x64.msix` installable via double-click; creates Start Menu entry; registers `.msix` as trusted (dev certificate OK for dev); AppInstaller update enabled.
2. LINUX: `packaging/build-linux.sh` SHALL produce: `mc-gui-<version>-x86_64.AppImage` (runs on any distro), `mc-gui-<version>.flatpak` (Flatpak manifest), `mc-gui-<version>-x64.deb` (Debian/Ubuntu), `mc-gui-<version>-x64.rpm` (Fedora/RHEL); all with `.desktop` entry, hicolor icons, MIME type `inode/directory` for folder opening.
3. MACOS: existing `build-macos.sh` produces `.dmg` (already done).
4. ALL installers SHALL include correct version metadata, icon, app name "Midnight Commander GUI", bundle ID.
5. CI SHALL build and test all installers on respective runners; upload as release artifacts.

**Independent Test**: Baixar `.msix` no Windows → instalar → Start Menu → rodar; Baixar `.AppImage` no Linux → `chmod +x` → rodar; Baixar `.dmg` no macOS → arrastar para Applications → rodar.

---

### P2: Ajustes cross-platform de UI/UX ⭐ MVP

**User Story**: Como usuário em Windows/Linux, quero que atalhos, diálogos, e comportamentos sigam convenções do meu SO, para sentir-se nativo.

**Why P2**: Polimento cross-platform; evita "uncanny valley" de app portado.

**Acceptance Criteria**:

1. KEYBOARD shortcuts: Windows/Linux usam `Ctrl` para a maioria (ex.: `Ctrl+C` copy, `Ctrl+V` paste); macOS usa `Cmd`. `KeyGestureMap` SHALL map `Ctrl`↔`Cmd` based on `OperatingSystem.IsMacOS()`.
2. FILE dialogs: SHALL use native OS file dialogs where available (Avalonia `FileDialog` defaults to native on Windows/macOS; Linux uses portal/Gtk).
3. PATH handling: `Path.DirectorySeparatorChar` used throughout; no hardcoded `/` or `\`.
4. CASE sensitivity: Linux filesystem case-sensitive; Windows/macOS case-insensitive (default). Search/comparison logic SHALL respect OS behavior.
5. LINE endings: Config files (JSON) written with `Environment.NewLine` (LF on Unix, CRLF on Windows); Git handles via `.gitattributes`.
6. MENU bar: macOS uses native menu bar (done); Windows/Linux use in-window menu bar (Avalonia `Menu` inside window).

---

## Edge Cases

- IF Windows user has no Recycle Bin (disabled) THEN `WindowsTrashService` SHALL fall back to permanent delete with warning.
- IF Linux user has no `libsecret` / D-Bus session THEN `LinuxCredentialStore` SHALL fall back to encrypted file (`~/.config/mc-gui/credentials.enc`) with master password prompt.
- IF `notify-send` not installed THEN `LinuxNotificationService` SHALL fall back to in-app toast (Avalonia `Window` overlay).
- IF MSIX signing certificate expired THEN build SHALL fail with clear error; dev cert auto-renewal documented.
- IF AppImage fails on older glibc THEN build SHALL use `linuxdeploy` with `--appimage-extract-and-run` fallback.
- CASE sensitivity bugs: test suite SHALL include case-sensitive filesystem tests (Linux) and case-insensitive (Windows/macOS).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| XPL-01 | P1: Infra Windows | Specify | Pending |
| XPL-02 | P1: Infra Windows | Specify | Pending |
| XPL-03 | P1: Infra Windows | Specify | Pending |
| XPL-04 | P1: Infra Windows | Specify | Pending |
| XPL-05 | P1: Infra Windows | Specify | Pending |
| XPL-06 | P1: Infra Windows | Specify | Pending |
| XPL-07 | P1: Infra Linux | Specify | Pending |
| XPL-08 | P1: Infra Linux | Specify | Pending |
| XPL-09 | P1: Infra Linux | Specify | Pending |
| XPL-10 | P1: Infra Linux | Specify | Pending |
| XPL-11 | P1: Instaladores | Specify | Pending |
| XPL-12 | P1: Instaladores | Specify | Pending |
| XPL-13 | P1: Instaladores | Specify | Pending |
| XPL-14 | P1: Instaladores | Specify | Pending |
| XPL-15 | P1: Instaladores | Specify | Pending |
| XPL-16 | P2: Ajustes UI cross-platform | Specify | Pending |
| XPL-17 | P2: Ajustes UI cross-platform | Specify | Pending |
| XPL-18 | P2: Ajustes UI cross-platform | Specify | Pending |
| XPL-19 | P2: Ajustes UI cross-platform | Specify | Pending |
| XPL-20 | P2: Ajustes UI cross-platform | Specify | Pending |

**ID format:** `XPL-NN` (Cross-Platform)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 20 total, 0 mapped to tasks, 20 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] `McGui.Infrastructure.Windows` e `McGui.Infrastructure.Linux` compilam e passam todos os testes de contrato (236+ testes totais passam em macOS, Windows, Linux).
- [ ] Instaladores: `.msix` (Windows), `.AppImage`/`.flatpak`/`.deb`/`.rpm` (Linux), `.dmg` (macOS) gerados no CI e funcionais.
- [ ] UI cross-platform: atalhos `Ctrl`/`Cmd` corretos; file dialogs nativos; paths/separadores corretos; menu bar in-window no Win/Linux.
- [ ] CI matrix roda em `macos-14` (arm64), `ubuntu-latest` (x64), `windows-latest` (x64); todos os testes passam.
- [ ] Release GitHub Action publica todos os 7+ artifacts (dmg, msix, AppImage, flatpak, deb, rpm) em tag.
- [ ] Suite de testes existente (236) continua passando nas 3 plataformas; novos testes cross-platform.
- [ ] Build com `-warnaserror` limpo em todas plataformas.