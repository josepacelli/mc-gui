# Subshell / Command Line Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje não tem subshell nem linha de comando integrada. O Midnight Commander original possui um subshell concorrente (shell real rodando em background, tipicamente bash/zsh/fish) que permite: executar comandos shell a partir da linha de comando do MC (prompt na parte inferior), alternar entre MC e subshell (Ctrl+O), ver output de comandos, e usar o shell para autocompletar paths na linha de comando do MC. O subshell usa PTY (pseudo-terminal) para comunicação bidirecional. Esta feature entrega o subshell no mc-gui: terminal embutido (via `Terminal.Gui` ou similar) na parte inferior da janela principal, alternável via Ctrl+O, com linha de comando integrada no topo dos painéis (ou barra separada), histórico de comandos, autocompletar paths do painel atual, e integração com operações do MC (seleção de arquivos → `$MC_FILES` env var).

## Goals

- [ ] Área de terminal embutida na parte inferior da janela principal (height configurável, default 40% da janela), oculta por padrão.
- [ ] Ctrl+O alterna visibilidade do terminal (mostra/esconde); estado persistido.
- [ ] Terminal roda shell do usuário (`$SHELL` ou bash/zsh/fish) via PTY; suporta cores, curses apps (vim, htop, less), e input completo.
- [ ] Linha de comando integrada: barra de input no topo do terminal (ou separada) com prompt do shell; Enter executa; Ctrl+C envia SIGINT; Ctrl+Z suspende.
- [ ] Histórico de comandos (seta cima/baixo navega); persistido entre sessões (`~/.config/mc-gui/shell-history.txt`).
- [ ] Autocompletar (Tab): completa comandos, paths relativos ao painel ativo, variáveis de ambiente, variáveis MC (`%f`, `%d`, `%D`, `%t`).
- [ ] Variáveis de ambiente MC injetadas no subshell: `MC_PWD` (dir painel ativo), `MC_FILE` (arquivo cursor), `MC_FILES` (arquivos marcados space-separated), `MC_OTHER_PWD` (dir painel oposto).
- [ ] Output do subshell: scrollback buffer (configurável, default 10000 linhas); busca no output (Ctrl+Shift+F); copiar seleção (Ctrl+Shift+C).
- [ ] Menu `Command > Subshell` habilitado com itens: `Show/Hide` (Ctrl+O), `Restart shell`, `Clear scrollback`, `Paste`, `Copy`.
- [ ] Integração com operações MC: selecionar arquivos no painel → variável `$MC_FILES` disponível no shell para uso em scripts/comandos.

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Múltiplos tabs de terminal | Feature futura; MVP tem um shell |
| Perfis de shell salvos (diferentes shells/configs) | Complexidade; `$SHELL` padrão cobre 90% |
| Integração com `tmux`/`screen` | Fora do escopo; subshell é interno |
| Scripting/automation API para subshell | Feature futura (REPL/remote control) |
| Suporte a Windows PTY (ConPTY) | Windows é fase futura; macOS/Linux usam PTY padrão |
| Theming do terminal independente | Usa tema do app (Light/Dark) |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Terminal widget | `Terminal.Gui` (NuGet, MIT) ou `AvaloniaTerminal` — terminal emulado completo com PTY, cores, curses | Evita reimplementar terminal; maduro | n |
| PTY no macOS | `posix_openpt`/`grantpt`/`unlockpt` + `fork`/`exec`; ou `System.Diagnostics.Process` com `ProcessStartInfo.UseShellExecute=false` + redirecionamento | .NET 8+ suporta PTY nativo via `Process` | n |
| Shell detection | `$SHELL` env var; fallback `/bin/bash` → `/bin/zsh` → `/bin/sh` | Padrão Unix | n |
| Linha de comando | Input bar separada acima do terminal (estilo MC) OU integrada no terminal (prompt do shell) | MC original tem prompt separado; GUI pode unificar | n |
| Scrollback | Buffer circular em memória (default 10000 linhas); opção "Clear scrollback" no menu | Performance | n |
| Autocompletar paths | Tab completa: comandos (PATH), arquivos relativos a `MC_PWD`, variáveis `$`, macros MC (`%f`→`$MC_FILE`) | Power user feature | n |
| MC_FILES format | Space-separated, cada path quoted se contém espaços: `'path with spaces' otherpath` | Shell-safe | n |
| Testes | Unit: SubshellService (env vars, macro expansion); Integration: PTY spawn, command exec, output capture; UAT: Ctrl+O, Tab complete, cores | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Terminal embutido com Ctrl+O ⭐ MVP

**User Story**: Como usuário, quero pressionar Ctrl+O e ver um terminal real (bash/zsh) na parte inferior do mc-gui, para rodar comandos sem sair do gerenciador.

**Why P1**: Subshell é feature icônica do MC; diferencial para power users.

**Acceptance Criteria**:

1. WHEN the user presses Ctrl+O THEN a terminal pane SHALL appear at the bottom of the main window (height 40% default, resizable via splitter), running the user's `$SHELL`.
2. WHEN the user presses Ctrl+O again THEN the terminal pane SHALL hide (state preserved: scrollback, running process).
3. THE terminal SHALL support full VT100/ANSI: colors (ls --color, grep --color), cursor positioning (vim, htop, less), mouse (se app suporta), e input completo.
4. THE terminal SHALL have a scrollback buffer (default 10000 lines) navigable via mouse wheel, PageUp/PageDown, or scrollbar.
5. WHEN the user types in the terminal THEN keystrokes SHALL be sent to the shell PTY; output SHALL appear in real-time.

**Independent Test**: Ctrl+O → terminal abre com prompt bash; `ls --color` mostra cores; `vim file` abre editor; Ctrl+O esconde; Ctrl+O mostra de novo com estado preservado.

---

### P1: Linha de comando com autocompletar e variáveis MC ⭐ MVP

**User Story**: Como usuário, quero digitar comandos no subshell com autocompletar de paths do painel atual e variáveis `%f`/`%d` expandidas, para operar rápido nos arquivos selecionados.

**Why P1**: Integração painel↔shell é o poder do MC; autocompletar acelera workflow.

**Acceptance Criteria**:

1. THE terminal SHALL provide an input line (prompt do shell) where user types commands; Tab triggers completion.
2. TAB completion SHALL complete: executable names (from `$PATH`), file/directory paths relative to `MC_PWD` (active panel dir), environment variables (`$VAR`), and MC macros (`%f` → `$MC_FILE`, `%d` → `$MC_PWD`, `%D` → `$MC_OTHER_PWD`, `%t` → `$MC_FILES`).
3. WHEN the user presses Tab on `%f` THEN it SHALL expand to the current file under cursor (quoted if spaces).
4. WHEN the user presses Tab on `%t` THEN it SHALL expand to space-separated list of marked files (each quoted).
5. THE shell environment SHALL include: `MC_PWD`, `MC_FILE`, `MC_FILES`, `MC_OTHER_PWD` updated on panel navigation/selection changes.

**Independent Test**: No painel, marcar 2 arquivos, Ctrl+O → digita `cp %t /tmp/` + Tab → expande para `cp 'file1.txt' 'file2.txt' /tmp/`; Enter executa copia.

---

### P1: Histórico, scrollback, e integração menu ⭐ MVP

**User Story**: Como usuário, quero histórico de comandos persistido, scrollback no output, e menu Command > Subshell funcional.

**Why P1**: UX completa de terminal; expectativa básica.

**Acceptance Criteria**:

1. COMMAND history SHALL persist to `~/.config/mc-gui/shell-history.txt` (one per line); Up/Down arrows navigate history in terminal input.
2. SCROLLBACK buffer SHALL retain last 10000 lines; mouse wheel / PageUp / scrollbar navigate history; Ctrl+Shift+F opens search in scrollback.
3. MENU `Command > Subshell` SHALL have: `Show/Hide` (Ctrl+O), `Restart shell` (kills current, spawns new), `Clear scrollback`, `Paste` (from clipboard to shell input), `Copy` (copies selection from scrollback).
4. SELECTION in scrollback: mouse drag selects text; Ctrl+Shift+C copies; right-click context menu: Copy, Select All, Clear Selection.

**Independent Test**: Rodar 5 comandos, fechar app, reabrir, Ctrl+O → Up arrow mostra histórico; scroll PageUp vê output antigo; Ctrl+Shift+F busca "error"; menu Subshell > Clear scrollback limpa.

---

### P2: Integração avançada: seleção painel → shell ⭐ MVP

**User Story**: Como usuário, quero selecionar arquivos no painel e usar `$MC_FILES` no shell para processá-los em lote (ex.: `for f in $MC_FILES; do gzip $f; done`).

**Why P2**: Workflow clássico MC; poder do subshell.

**Acceptance Criteria**:

1. WHEN the user marks files in the active panel THEN `MC_FILES` environment variable SHALL be updated in the subshell process (space-separated, quoted).
2. WHEN the user changes the active panel selection THEN `MC_FILES`, `MC_FILE`, `MC_PWD`, `MC_OTHER_PWD` SHALL be updated in real-time (via env update mechanism ou reinject no shell via `export`).
3. THE subshell SHALL receive `SIGWINCH` on terminal resize (splitter drag) to update `LINES`/`COLUMNS`.

**Independent Test**: Marcar 3 arquivos, Ctrl+O → `echo $MC_FILES` mostra 3 paths quoted; desmarcar → `echo $MC_FILES` vazio; redimensionar splitter → `echo $LINES $COLUMNS` atualiza.

---

## Edge Cases

- IF the shell process crashes/exits THEN the terminal SHALL show "[Shell exited, press Enter to restart]" and Ctrl+O re-spawns.
- IF the user runs a long-running command (e.g., `sleep 100`) and hides terminal with Ctrl+O THEN the command continues running; showing terminal again shows current output.
- IF the user runs a curses app (vim, htop) THEN it SHALL work correctly; Ctrl+O hides terminal but app keeps running (or suspends via Ctrl+Z).
- IF the PTY fails to allocate THEN show error dialog "Cannot start subshell: [error]" and disable Ctrl+O / Subshell menu.
- IF the shell is fish/zsh com prompt complexo (git branch, etc.) THEN prompt SHALL render correctly (ANSI support).
- MAXIMUM scrollback lines: configurable (default 10000, max 100000); older lines dropped.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| SUB-01 | P1: Terminal + Ctrl+O | Specify | Pending |
| SUB-02 | P1: Terminal + Ctrl+O | Specify | Pending |
| SUB-03 | P1: Terminal + Ctrl+O | Specify | Pending |
| SUB-04 | P1: Terminal + Ctrl+O | Specify | Pending |
| SUB-05 | P1: Terminal + Ctrl+O | Specify | Pending |
| SUB-06 | P1: Linha comando + autocomplete | Specify | Pending |
| SUB-07 | P1: Linha comando + autocomplete | Specify | Pending |
| SUB-08 | P1: Linha comando + autocomplete | Specify | Pending |
| SUB-09 | P1: Linha comando + autocomplete | Specify | Pending |
| SUB-10 | P1: Linha comando + autocomplete | Specify | Pending |
| SUB-11 | P1: Histórico + scrollback + menu | Specify | Pending |
| SUB-12 | P1: Histórico + scrollback + menu | Specify | Pending |
| SUB-13 | P1: Histórico + scrollback + menu | Specify | Pending |
| SUB-14 | P1: Histórico + scrollback + menu | Specify | Pending |
| SUB-15 | P2: Integração painel↔shell | Specify | Pending |
| SUB-16 | P2: Integração painel↔shell | Specify | Pending |
| SUB-17 | P2: Integração painel↔shell | Specify | Pending |

**ID format:** `SUB-NN` (Subshell)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 17 total, 0 mapped to tasks, 17 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] Ctrl+O mostra/esconde terminal inferior com shell real; cores/curses/input funcionam.
- [ ] Tab autocompleta paths do painel, comandos, vars, macros `%f`/%d/%D/%t.
- [ ] Variáveis `MC_PWD`, `MC_FILE`, `MC_FILES`, `MC_OTHER_PWD` injetadas e atualizadas.
- [ ] Histórico persistido; scrollback 10k linhas; busca Ctrl+Shift+F; menu Subshell funcional.
- [ ] Seleção painel → `$MC_FILES` disponível no shell para loops/scripts.
- [ ] Menu `Command > Subshell` habilitado; Ctrl+O toggle; Restart/Clear/Paste/Copy.
- [ ] Suite de testes existente (236) continua passando; novos testes: unit SubshellService, integração PTY.
- [ ] Build com `-warnaserror` limpo.