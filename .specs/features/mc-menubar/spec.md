# MC Menu Bar Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje exibe uma menubar no topo com **apenas** o menu `Theme` (claro/escuro). O Midnight Commander original tem uma menubar completa acionada por F9 (barra superior) com cinco menus: `Left`, `File`, `Command`, `Options`, `Right` — onde `Right` espelha `Left` (em split horizontal: `Above`/`Below`). A definição canônica está em `../mc/src/filemanager/filemanager.c` (`create_panel_menu`, `create_file_menu`, `create_command_menu`, `create_options_menu`, `init_menu`).

Esta feature (fatia B) substitui a menubar atual por uma réplica fiel da estrutura do MC: os quatro conjuntos de itens com os textos/ordem/separadores originais (mnemônicos preservados), sempre visível no topo, com F9 ativando o primeiro menu. Itens cujas funções ainda não existem no mc-gui aparecem **desabilitados**; itens de funções já existentes ficam habilitados e acionam o comando equivalente. O menu `Theme` (claro/escuro) da feature anterior é **movido para dentro de `Options`**.

## Goals

- [ ] Menubar superior sempre visível exibindo os menus `Left`, `File`, `Command`, `Options`, `Right` na ordem e com os itens do MC original (`filemanager.c`), `Right` espelhando `Left`.
- [ ] Itens de funções implementadas no mc-gui habilitados e acionando a ação correspondente (Copy/Move/Mkdir/Delete/Rescan/Select-group/Unselect/Invert/Quit/Refresh e afins); demais itens (Viewer, Editor, chmod, VFS, hotlist etc.) desabilitados.
- [ ] Mnemônicos do original preservados e acionáveis; F9 abre o primeiro menu (e navegação de teclado pela barra).
- [ ] Menu `Theme` (System/Light/Dark) movido p/ `Options`, sem perda das ACs de theming (THM-11..18) existentes.

## Out of Scope

Explicitamente excluído desta fatia.

| Feature | Motivo |
| --- | --- |
| Implementar as funções desabilitadas (viewer F3, editor F4, chmod/chown, VFS/FTP, hotlist, find-file, tree, panelize, compare dirs, etc.) | Cada uma é feature própria; aqui só aparecem desabilitadas |
| Diálogos/subtelas dessas funções | Fora de escopo |
| Config de itens de menu pelo usuário (menu do usuário F2 editável) | Feature futura própria (usermenu) |
| Menubar oculta (só via F9) | Decisão: sempre visível (estilo GUI) |
| Temas/estilo da menubar além do Fluent | Consistente com tema atual |
| Atalhos novos além do F9/mnemônicos | Manter keymap atual |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Estrutura | Menus `Left`, `File`, `Command`, `Options`, `Right` (Right = clone de Left) na ordem do `init_menu` do MC | Fonte canônica `filemanager.c:319-327` | y |
| `Theme` | Menu Theme vira submenu/item dentro de `Options` (mantendo System/Light/Dark) | Decisão do usuário; MC não tem Theme, Options é o local natural | y |
| Itens inexistentes | Desabilitados, com texto/mnemônico originais | Decisão do usuário "todos, desabilitar ausentes" | y |
| Mnemônicos | `&X` do original mapeado p/ mnemônico Avalonia; acionável por Alt+tecla e navegação de teclado da barra | Original usa `_("&File")` etc. | y |
| F9 | F9 abre/ativa a menubar (primeiro menu fica aberto), comportamento padrão MC; menubar continua sempre visível | Decisão | y |
| Divisão horizontal | Labels `Left`/`Right` (não Above/Below) por ora; app é split vertical sempre | mc-gui não tem toggle horizontal hoje | y |
| `Command > User menu`/`Edit menu file` etc. | Desabilitados (usermenu é feature futura) | Out of scope | y |
| Disabled não clicável | Menus/itens desabilitados não respondem a clique nem acelerador | Convenção Avalonia | y |
| Testes | Estrutura (textos/itens/habilitados por categoria) testável via modelo de dados puro; renderização visual por build-gate + UAT; ACs de theming existentes (menu Theme dentro de Options) cobertos pelos testes atuais de VM | Padrão: lógica em testes + UAT | y |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Menubar MC completa (Left/File/Command/Options/Right) ⭐ MVP

**User Story**: As a usuário, I want a menubar no topo com os mesmos menus/itens do Midnight Commander, so that a interface tem paridade com o original.

**Why P1**: Núcleo do pedido.

**Acceptance Criteria** (cada linha é um padrão EARS):

1. The app SHALL show a top-level menu bar containing the menus `Left`, `File`, `Command`, `Options`, and `Right` in that order. <!-- ubiquitous -->
2. The `Right` menu SHALL expose the same item set as the `Left` menu. <!-- ubiquitous -->
3. The `File`, `Command`, and `Options` menus SHALL list exactly the items defined for them in the original MC (`../mc/src/filemanager/filemanager.c`, functions `create_file_menu`, `create_command_menu`, `create_options_menu`), in the original order, with the original separators. <!-- ubiquitous -->
4. WHEN the menu bar is not in use THEN it SHALL remain visible at the top of the window. <!-- state-driven -->

**Independent Test**: Executar app; menubar no topo com 5 menus; conferir cada dropdown contra a lista do `filemanager.c`.

---

### P1: Itens funcionais habilitados, inexistentes desabilitados ⭐ MVP

**User Story**: As a usuário, I want que itens de menu cuja função existe no mc-gui estejam clicáveis e os demais apareçam desabilitados, so that não há promessa de função que não funciona.

**Why P1**: Evita itens que parecem ativos mas não fazem nada.

**Acceptance Criteria**:

1. WHEN the app starts THEN the following menu items SHALL be enabled: File > Copy (F5), File > Rename/Move (F6), File > Mkdir (F7), File > Delete (F8), File > Rescan, File > Select group, File > Unselect group, File > Invert selection, File > Exit, Command > Swap panels (se implementado), Options > Theme. <!-- event-driven -->
2. WHEN a disabled menu item is clicked THEN no operation SHALL be triggered. <!-- unwanted-behavior -->
3. WHEN an enabled item is activated THEN the equivalent mc-gui action SHALL run (Copy/Move/Mkdir/Delete/Refresh/Mark/Unmark/Invert/Quit/Theme). <!-- event-driven -->
4. The disabled set SHALL include at least: File > View, File > View file..., File > Filtered view, File > Edit, File > chmod, File > chown, File > Link/Symlink, File > Quick cd, File > Exit is ENABLED; Command > User menu, Directory tree, Find file, Compare dirs, Hotlist, VFS list, Background jobs; Options > Configuration/Layout/Panel options/Learn keys/Virtual FS (per original); editor/viewer commands. <!-- ubiquitous -->
5. `Options > Theme` SHALL be enabled and SHALL open the same System/Light/Dark behavior of the previous `Theme` top-level menu. <!-- ubiquitous -->

**Independent Test**: Clicar View/Edit não faz nada; clicar Copy abre o diálogo de cópia; Theme dentro de Options alterna tema.

---

### P1: Mnemônicos + F9 ⭐ MVP

**User Story**: As a usuário, I want navegar a menubar por teclado (F9 abre; Alt+mnemônico e setas), so that opero sem mouse como no MC.

**Why P1**: mc-gui é teclado-cêntrico.

**Acceptance Criteria**:

1. WHEN the user presses F9 THEN the first menu (`Left`) SHALL open/activate. <!-- event-driven -->
2. WHEN a menu is open THEN the arrow keys SHALL navigate between menus and items, and Enter SHALL activate the selected item. <!-- event-driven -->
3. WHEN the user presses Alt + the mnemonic key of a top menu SHALL that menu open; inside a menu, the mnemonic key SHALL activate the matching item. <!-- event-driven -->

**Independent Test**: F9 abre; Alt+F abre File; setas navegam; Enter ativa.

---

## Edge Cases

- IF the menu bar has only disabled items in a submenu THEN the submenu SHALL still render and close normally (no crash). <!-- unwanted-behavior -->
- WHEN a menu item is both disabled and has an accelerator (e.g. F3 View) THEN pressing the accelerator SHALL do nothing (the keymap already guards disabled actions). <!-- event-driven -->
- WHEN the user opens Options > Theme and changes theme THEN the menu bar colors SHALL update with the theme. <!-- event-driven -->

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| MB-01 | P1: Menubar completa | Design | Verified |
| MB-02 | P1: Menubar completa | Design | Verified |
| MB-03 | P1: Menubar completa | Design | Verified |
| MB-04 | P1: Menubar completa | Design | Verified |
| MB-05 | P1: Itens hab/des | Design | Verified |
| MB-06 | P1: Itens hab/des | Design | Verified |
| MB-07 | P1: Itens hab/des | Design | Verified |
| MB-08 | P1: Itens hab/des | Design | Verified |
| MB-09 | P1: Itens hab/des | Design | Verified |
| MB-10 | P1: Mnemônicos+F9 | Design | Verified |
| MB-11 | P1: Mnemônicos+F9 | Design | Verified |
| MB-12 | P1: Mnemônicos+F9 | Design | Verified |

**ID format:** `MB-N` (Menu Bar)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 12 total, 12 mapped to tasks, 0 unmapped

---

## Success Criteria

- [ ] Menubar com 5 menus replicando item a item (texto/ordem/separador) do `filemanager.c`; `Right` = `Left`.
- [ ] Itens funcionais disparam ações reais; desabilitados inertes; Theme dentro de Options funciona.
- [ ] F9 + mnemônicos + setas operam a barra; testes atuais de theming (menu Theme) continuam verdes após mover p/ Options.
- [ ] Full gate verde.
