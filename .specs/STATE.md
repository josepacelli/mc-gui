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
- **Feature `copy-move-mc-options`**: **spec + design + tasks prontos, Execute ainda não rodado** (usuário pediu explicitamente "criar a feature para executar depois"). 3 stories: P1 opção "Update" no prompt de conflito (só sobrescreve se origem mais nova), P2 checkbox "Preservar atributos" (permissão Unix + timestamp via `File.SetUnixFileMode`/`GetUnixFileMode`, confirmado via Microsoft Learn), P3 checkbox "Seguir links" (symlink copiado como link vs. conteúdo seguido, via `File.CreateSymbolicLink`). 10 tasks (T1-T10), `CopyMoveOptions` novo record em `McGui.Core`, mudança de assinatura em `IFileSystemService.CopyAsync`/`MoveAsync`. Recursão em subdiretórios e conflito Overwrite/Skip/Rename/Abort **já existiam** antes desta spec - não eram o gap real.
- **Next step**: (1) decidir se empurra o commit `56c4071` pro origin; (2) quando o usuário disser "implementar copy/move" ou similar, ativar o skill `tlc-spec-driven`, ler `.specs/features/copy-move-mc-options/{spec,design,tasks}.md` do zero (não assumir contexto desta sessão) e seguir o Execute normal (10 tasks, Verifier automático no final). Backlog MC ainda pendente: viewer F3, editor F4, chmod/chown, links, VFS/FTP, hotlist, usermenu F2 (mesmo bug do F1/F9/F10); refinamento do ícone; assinatura/notarização; installers Win/Linux.
- **Blockers**: none
- **Uncommitted files**: este `STATE.md` (handoff atual).
- **Branch**: main, 1 commit local à frente de origin (`56c4071`, fix F1/F9/F10) — pedir go-ahead antes de push.
