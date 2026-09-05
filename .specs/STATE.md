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

- **Feature**: `panel-icons-dotdot` (`.specs/features/panel-icons-dotdot/`) — **DONE**.
- **Execute**: T1-T7 commitadas (`f863ee7`..`da718c6`), T8 full gate + UAT (`7880d66`, gap ícone `6575009`), Verifier independente FAIL→Fix 1 (M6/PII-15) → re-verify **PASS** (`ee3613b`; 17/17 ACs, sensor 6/6, PII-01..17 Verified). `validate_state.py` 0 erros.
- **Completed**: 151 testes (17 Core + 31 Infra + 103 App). Working tree limpo, branch `main`.
- **Decisões**: `..` = FileEntry virtual (`Name=".."`) injetado no topo de `PanelState.Entries` pelo PanelViewModel (exceto raiz `/`); `SelectionService` guarda por nome `..` (Toggle/invert/pattern/unmark); `GetOperationSources` exclui `..`; ativar `..`/Backspace sobe pousando cursor na pasta de origem; descer pousa no 1º real; `FileSizeFormatter` base 1024 (B/kB/MB/GB/TB, ≤1 casa, dir/`..` vazio); ícones `PathIcon` pasta(`FolderIconBrush`)/arquivo(`FileIconBrush`) novos tokens na paleta.
- **UAT notes**: app GUI às vezes falha com `Avalonia.Native -6661` (RenderTimer) ao abrir remoto via `dotnet run` — requer sessão gráfica; alternar matar processos (`pkill -9 -f McGui`) e relançar.
- **Next step**: **Feature B — menubar F9 replicando o MC original** (`../mc/src/filemanager/filemanager.c`: menus Left/File/Command/Options/Right; ~50 itens, ausentes desabilitados, mnemonics + teclado). Especificar primeiro via `tlc-spec-driven`.
- **Blockers**: none
- **Uncommitted files**: este `STATE.md` (handoff atual).
- **Branch**: main (origin/main em `568d20e`; commits locais desde então NÃO pushados — requer go-ahead).
