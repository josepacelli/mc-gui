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

- **Feature `macos-native-chrome`**: **DONE**, verificada e pushed (`699daca`, push confirmado em `350e7fa..350e7fa` no início desta sessão).
- **Bug fix `F1/F9/F10`**: botões da barra de função não executavam nada (nem clique nem tecla, exceto F9 que já funcionava via teclado). Corrigido em `56c4071` (commit local, **não pushed**): F9 chama `OpenFirstMenu()` (Click), F10 chama `Close()` (Click + `case GestureAction.Quit` novo no `OnKeyDown`), F1 desabilitado (sem viewer de Help implementado, mesmo padrão de F3/F4) e `GestureAction.Help`/`UserMenu` entraram em `KeyGestureMap.DisabledActions`. 219 testes, 0 falhas. **F2 "Menu" tem o mesmo problema (sem Command) mas não foi tocado - fora do escopo pedido, flagar se usuário quiser.**
- **Feature `copy-move-mc-options`**: **DONE** — Execute completo com 10 tasks (T1-T10), Verifier PASS. Adicionada opção "Update" no prompt de conflito, checkbox "Preservar atributos" (Unix mode + timestamp), checkbox "Seguir links" (symlink vs target content). 236 testes totais passam.
- **Feature `macos-installer`**: **DONE** — 4 tasks completas. Script `build-macos.sh` gera `.app` válido + DMG drag-to-install; workflow GitHub Actions `build-macos.yml` produz artifact e release em tag. DMG `mc-gui-0.1.0-arm64.dmg` em `artifacts/`.
- **Next step**: Specificar features restantes do MC original. Prioridade média: Viewer (F3), Editor (F4), VFS (FTP/SFTP/archives), Hotlist/Bookmarks (Ctrl+\), User Menu (F2), Directory Tree, Find File (Alt+F7), Background Operations, Chmod/Chown/Chattr. Prioridade baixa: Help (F1), Diff Viewer, Subshell/Command Line, Configuration/Setup, Windows/Linux installers.
- **Blockers**: none
- **Uncommitted files**: este `STATE.md` (handoff atual).
- **Branch**: main, 12 commits locais à frente de origin — pedir go-ahead antes de push.

(End of file - total 18 lines)