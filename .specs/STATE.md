# STATE

## Decisions

### AD-001
- **Decision**: Solução organizada em 3 projetos por responsabilidade — `McGui.Core` (modelos + interfaces, sem dependência de SO), `McGui.Infrastructure.<Plataforma>` (implementação real por SO, ex.: `McGui.Infrastructure.macOS`), `McGui.App` (Avalonia UI/ViewModels).
- **Reason**: O projeto tem como objetivo declarado ser um clone completo multiplataforma (Windows/macOS/Linux) do Midnight Commander, entregue primeiro em macOS. Isolar código específico de SO atrás de interfaces desde a primeira feature evita reescrever `Core`/`App` ao portar para as próximas plataformas.
- **Trade-off**: Mais projetos/arquivos de configuração para manter desde o início, comparado a um monolito de projeto único.
- **Scope**: Toda feature futura que envolva acesso a sistema de arquivos, diálogos nativos, ou qualquer API específica de SO deve seguir este padrão de camadas.
- **Date**: 2026-09-05
- **Status**: active

## Handoff

- **Feature**: `macos-installer` (`.specs/features/macos-installer/`) — **DONE**.
- **Execute**: T1-T4 + Verifier independente **PASS** (13/13, sensor 3/3) — `dbfe690`..`7d9b625`. Release `v0.1.0` criada no GitHub com asset `mc-gui-0.1.0-arm64.dmg`.
- **Completed**: 180 testes (17 Core + 31 Infra + 132 App). Working tree limpo, branch `main`; origin atualizado (push + tag v0.1.0 feitos c/ go-ahead).
- **Entregue**: `packaging/build-macos.sh` (publish self-contained osx-arm64 → bundle `Midnight Commander GUI.app` → DMG drag-to-install), `packaging/Info.plist` (id `mcgui.jpmo.dev.br`, CFBundleName `MC GUI` ≤15, CFBundleDisplayName `Midnight Commander GUI`, versão por arg), `packaging/make-icon.sh` (icns de PNG commitado em `packaging/icon-asset/`, sem PIL p/ CI), `.github/workflows/build-macos.yml` (macos-14; DMG artifact + release em tag `v*`, prefixo `v` removido). Título da janela → "Midnight Commander GUI".
- **Decisões**: sem assinatura/notarização (dev; Gatekeeper pede clique-direito+Abrir); só arm64; ícone commitado (PIL removido — spec atualizado); DMG 0.1.0 padrão, versão por `$1`.
- **Next step**: aguardando próxima feature do usuário. Backlog MC: viewer F3, editor F4, chmod/chown, links, VFS/FTP, hotlist, usermenu F2; refinamento do ícone (design); assinatura/notarização p/ distribuição pública; installers Win/Linux.
- **Blockers**: none
- **Uncommitted files**: este `STATE.md` (handoff atual).
- **Branch**: main (origin/main sincronizado; tag v0.1.0 no origin).
