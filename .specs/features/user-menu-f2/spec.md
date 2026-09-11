# User Menu (F2) Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje tem o item de menu `Command > User menu` desabilitado. O Midnight Commander original possui um menu de usuário (F2) totalmente personalizável, armazenado em `~/.config/mc/menu` (ou `~/.mc/menu`), onde o usuário pode definir comandos shell arbitrários com macros de substituição (ex.: `%f` = arquivo atual, `%d` = diretório atual, `%D` = diretório do painel oposto, `%t` = arquivo(s) marcado(s), `%u`/`%U` = usuário/grupo). O menu suporta submenus, separadores, e executa comandos no subshell do MC. Esta feature entrega o User Menu no mc-gui, acessível via F2 e menu `Command > User menu`, com: editor de menu integrado, macros de substituição, execução de comandos (locais e via shell), suporte a submenus, e persistência em arquivo de config.

## Goals

- [ ] Pressionar F2 abre o User Menu (dropdown ou janela) com itens definidos pelo usuário.
- [ ] Menu `Command > User menu` habilitado e funcional (mesmo que F2).
- [ ] Editor de menu acessível via `Command > Edit menu file` (ou botão no User Menu) para adicionar/editar/remover/reordenar itens.
- [ ] Itens de menu suportam: label (com mnemonic `&`), comando shell, submenu (início/fim), separador.
- [ ] Macros de substituição no comando: `%f` (arquivo cursor), `%d` (dir painel ativo), `%D` (dir painel oposto), `%t` (arquivos marcados, espaço-separados), `%T` (arquivos marcados no painel oposto), `%v` (arquivo viewer), `%e` (arquivo editor), `%s` (seleção única), `%cd` (mudar dir antes de executar).
- [ ] Execução: comandos rodam via shell do SO (`/bin/sh -c` no Unix); output capturado e mostrado em painel/terminal embutido ou janela de output.
- [ ] Se comando falha (exit code != 0), mostrar erro com output stderr.
- [ ] Menu persiste em `~/.config/mc-gui/user-menu.json` (ou formato compatível MC).
- [ ] Itens podem ter condição de exibição (ex.: apenas se arquivo selecionado, apenas se diretório).

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Subshell interativo embutido (PTY) | Feature separada (Subshell/Command Line); user menu executa comandos discretos |
| Macros avançadas (`%b` basename, `%x` extension, etc.) | MC tem muitas; MVP cobre as essenciais listadas acima |
| Menu condicional por tipo de arquivo (magic) | Complexidade de detecção; feature futura |
| Histórico de comandos executados no user menu | Nice-to-have; history é feature separada |
| Integração com ferramentas externas (lint, format, test) | Exemplos de uso; não feature do menu em si |
| Sincronização de menu entre máquinas | Feature futura |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Formato do menu | JSON estruturado (array de itens com tipo: command/submenu/separator) em `~/.config/mc-gui/user-menu.json` | Legível, versionável, extensível | n |
| UI do menu | Dropdown anexado ao botão F2 na toolbar OU janela modal centralizada | Dropdown é mais próximo do MC terminal; janela permite editor melhor | n |
| UI do editor | Janela modal com lista de itens (TreeView), botões Add/Edit/Remove/Up/Down, painel de propriedades (label, command, macros help) | Editor visual amigável | n |
| Execução de comando | `Process.Start` com `/bin/sh -c "cmd"` no macOS/Linux; `cmd.exe /c` no Windows; working directory = `%d` | Cross-platform | n |
| Output do comando | Janela de output modal (scrollable, monospace) com botão Close; captura stdout+stderr; exit code | Não tem subshell PTY no MVP | n |
| Macros | Substituição simples string replace antes de executar; `%f`/`%d`/`%D`/`%t`/`%T`/`%v`/`%e`/`%s`/`%cd` | Cobrem 90% dos casos de uso MC | n |
| Variáveis de ambiente | Herda env do processo mc-gui + `MC_PWD=%d` `MC_FILE=%f` etc. | Útil para scripts | n |
| Testes | Unit: macro substitution, menu serialization, command execution (mock shell); UAT: editor UI, execução real | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: User Menu básico com execução de comandos ⭐ MVP

**User Story**: Como usuário, quero pressionar F2 e ver meu menu personalizado com comandos que operam sobre o arquivo/diretório atual, para automatizar tarefas repetitivas.

**Why P1**: F2/User Menu é feature icônica do MC; diferenciador para power users.

**Acceptance Criteria**:

1. WHEN the user presses F2 THEN the User Menu SHALL open showing the user-defined items (commands, submenus, separators).
2. WHEN the user selects a command item THEN the system SHALL expand macros (`%f`, `%d`, `%D`, `%t`, `%T`, `%v`, `%e`, `%s`, `%cd`) using current panel state and execute the command via shell.
3. WHEN the command executes THEN the system SHALL capture stdout/stderr/exit code and display in an output window (modal, scrollable, monospace).
4. IF the command exits with non-zero code THEN the output window SHALL highlight the error and show stderr prominently.
5. WHEN the user presses F10 or Esc in the User Menu THEN it SHALL close.

**Independent Test**: Definir item "Compile" → `gcc %f -o %b`; selecionar `.c`, F2 → Compile → output window mostra sucesso/erro.

---

### P1: Editor de menu integrado ⭐ MVP

**User Story**: Como usuário, quero editar meu User Menu (adicionar comandos, criar submenus, reordenar) sem editar arquivo JSON à mão.

**Why P1**: Usabilidade; MC original tem `Edit menu file` mas edita arquivo texto; GUI merece editor visual.

**Acceptance Criteria**:

1. THE User Menu SHALL have a button/item "Edit menu..." that opens the menu editor window.
2. THE menu editor SHALL display a hierarchical list of items (commands, submenus, separators) with drag-and-drop reordering.
3. WHEN the user adds a command item THEN a dialog SHALL prompt for: Label (with `&` for mnemonic), Command (with macros help tooltip), Condition (dropdown: Always / File selected / Directory / Marked files / VFS).
4. WHEN the user adds a submenu THEN a dialog SHALL prompt for Label; submenu appears as expandable node in tree.
5. WHEN the user adds a separator THEN a horizontal rule SHALL appear in the menu.
6. CHANGES SHALL be saved to config file immediately on dialog OK; User Menu updates live.

**Independent Test**: Abrir editor, add "Git Status" → `git status %d`, add submenu "Tools", mover itens, OK → F2 mostra menu atualizado.

---

### P1: Macros de substituição essenciais ⭐ MVP

**User Story**: Como usuário, quero usar `%f`, `%d`, `%D`, `%t` nos meus comandos, para que eles operem no contexto correto do painel.

**Why P1**: Sem macros o menu é estático; macros dão poder contextual.

**Acceptance Criteria**:

1. `%f` SHALL expand to the full path of the file under cursor in active panel (quoted if spaces).
2. `%d` SHALL expand to the current directory of active panel (quoted).
3. `%D` SHALL expand to the current directory of inactive panel (quoted).
4. `%t` SHALL expand to space-separated list of marked files in active panel (each quoted); empty if none marked.
5. `%T` SHALL expand to space-separated list of marked files in inactive panel (each quoted).
6. `%v` SHALL expand to the file currently open in viewer (if any).
7. `%e` SHALL expand to the file currently open in editor (if any).
8. `%s` SHALL expand to the single selected file (same as `%f` but only if exactly one; empty otherwise).
9. `%cd` SHALL cause the shell to `cd` to `%d` before executing the command (prefix `cd "%d" && `).

**Independent Test**: Item "Copy to other panel" → `cp %f %D/`; marca 3 arquivos, item "Archive" → `tar czf %D/archive.tar.gz %t`.

---

### P2: Persistência e compatibilidade ⭐ MVP

**User Story**: Como usuário, quero que meu menu sobreviva a reinícios e, idealmente, possa importar meu menu do MC original.

**Why P2**: Persistência é obrigatória; compatibilidade MC é diferencial.

**Acceptance Criteria**:

1. THE menu SHALL be saved to `~/.config/mc-gui/user-menu.json` on every change.
2. ON startup, the menu SHALL load from config; if missing, start with empty menu (or default template).
3. IF config is corrupted, SHALL log error and start empty without crash.
4. (Nice-to-have) IMPORT button in editor to read `~/.config/mc/menu` (MC format) and convert to JSON.

---

## Edge Cases

- IF no file is under cursor and command uses `%f` THEN macro expands to empty string; command may fail gracefully.
- IF marked files list is huge (`%t` very long) THEN command line may exceed OS limit; SHALL warn and suggest `%f` loop alternative.
- IF command contains `cd` or changes directory THEN `%cd` macro handles it; working directory for next command resets to panel dir.
- IF user menu file is edited externally (vim) THEN reload on next F2 open (file watcher or timestamp check).
- RECURSIVE submenus supported (submenu within submenu); max depth 10 to prevent stack overflow.
- KEYBOARD navigation in User Menu: Up/Down, Enter (activate), Right (enter submenu), Left (exit submenu), Esc (close).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| USR-01 | P1: User Menu básico | Specify | Pending |
| USR-02 | P1: User Menu básico | Specify | Pending |
| USR-03 | P1: User Menu básico | Specify | Pending |
| USR-04 | P1: User Menu básico | Specify | Pending |
| USR-05 | P1: User Menu básico | Specify | Pending |
| USR-06 | P1: Editor de menu | Specify | Pending |
| USR-07 | P1: Editor de menu | Specify | Pending |
| USR-08 | P1: Editor de menu | Specify | Pending |
| USR-09 | P1: Editor de menu | Specify | Pending |
| USR-10 | P1: Editor de menu | Specify | Pending |
| USR-11 | P1: Macros | Specify | Pending |
| USR-12 | P1: Macros | Specify | Pending |
| USR-13 | P1: Macros | Specify | Pending |
| USR-14 | P1: Macros | Specify | Pending |
| USR-15 | P1: Macros | Specify | Pending |
| USR-16 | P1: Macros | Specify | Pending |
| USR-17 | P1: Macros | Specify | Pending |
| USR-18 | P1: Macros | Specify | Pending |
| USR-19 | P2: Persistência | Specify | Pending |
| USR-20 | P2: Persistência | Specify | Pending |
| USR-21 | P2: Persistência | Specify | Pending |
| USR-22 | P2: Persistência | Specify | Pending |

**ID format:** `USR-NN` (User Menu)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 22 total, 0 mapped to tasks, 22 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] F2 abre User Menu com itens definidos; seleção executa comando com macros expandidas.
- [ ] Output window mostra stdout/stderr/exit code; erro destacado se exit code != 0.
- [ ] Editor de menu: add/edit/remove command/submenu/separator; drag-drop reorder; save persiste.
- [ ] Macros `%f`, `%d`, `%D`, `%t`, `%T`, `%v`, `%e`, `%s`, `%cd` funcionam corretamente.
- [ ] Menu persiste em `user-menu.json`; carrega no startup; JSON corrompido → vazio sem crash.
- [ ] Menu `Command > User menu` habilitado; `Command > Edit menu file` abre editor.
- [ ] Suite de testes existente (236) continua passando; novos testes: unit macros, editor, execução.
- [ ] Build com `-warnaserror` limpo.