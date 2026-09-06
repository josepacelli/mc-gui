# Hotlist / Bookmarks (Ctrl+\) Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje não tem sistema de bookmarks/hotlist. O Midnight Commander original possui uma hotlist (Ctrl+\) que permite salvar diretórios frequentemente acessados em grupos, com suporte a: adicionar diretório atual, remover, criar grupos, mover entradas entre grupos, e navegação rápida. A hotlist persiste entre sessões no arquivo de configuração do MC. Esta feature entrega o sistema de bookmarks no mc-gui, acessível via Ctrl+\ (atalho padrão MC) e menu `Command > Directory hotlist`, com: lista hierárquica de grupos/entradas, adicionar painel atual, editar/remover, navegar para entrada (define painel ativo), e persistência em config do usuário.

## Goals

- [ ] Pressionar Ctrl+\ abre diálogo/janela da hotlist com lista de grupos e entradas.
- [ ] Hotlist exibe estrutura hierárquica: grupos expansíveis/colapsáveis contendo entradas (diretórios).
- [ ] Botão/ação "Add current directory" adiciona o diretório do painel ativo à hotlist (prompt para nome/grupo).
- [ ] Botão/ação "Remove" remove entrada ou grupo selecionado (com confirmação).
- [ ] Botão/ação "New group" cria novo grupo na raiz ou dentro do grupo selecionado.
- [ ] Botão/ação "New entry" adiciona entrada manual (path + nome) ao grupo selecionado.
- [ ] Duplo-clique ou Enter em uma entrada navega o painel ativo para aquele diretório (suporta paths locais e VFS).
- [ ] Drag-and-drop para reordenar entradas e mover entre grupos.
- [ ] Hotlist persiste entre sessões (salva em config do usuário: `~/.config/mc-gui/hotlist.json`).
- [ ] Item de menu `Command > Directory hotlist` habilitado; atalho Ctrl+\ funcional.
- [ ] Integração com VFS: entradas podem ser paths `ftp://`, `sftp://`, `tar://`, etc.

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Sincronização de hotlist entre máquinas (cloud) | Feature futura; complexidade de sync/conflict resolution |
| Tags/labels em entradas além de grupos | MC original só tem grupos; tags é extensão |
| Busca/filtro dentro da hotlist | Lista costuma ser pequena; Ctrl+F no diálogo se necessário depois |
| Hotlist por painel (esquerda/direita separados) | MC original tem hotlist global; compartilhada |
| Atalhos numéricos (1-9 para primeiras entradas) | MC tem; GUI usa navegação por setas/Enter |
| Importação de hotlist do MC original (`~/.config/mc/hotlist`) | Nice-to-have; formato diferente; pode ser tool separado |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Formato de armazenamento | JSON em `~/.config/mc-gui/hotlist.json` (ou equivalente macOS/Windows/Linux) | Legível, versionável, fácil de migrar | n |
| UI | Diálogo modal (`Window`) com `TreeView`/`TreeDataGrid` para hierarquia; toolbar com botões Add/Remove/Group/Enter | Consistente com MC; `TreeView` nativo Avalonia | n |
| Atalho Ctrl+\ | `KeyGestureMap` mapeia `Ctrl+Backslash` → `OpenHotlistCommand` no `MainWindowViewModel` | MC original usa Ctrl+\ | n |
| Navegação | Duplo-clique ou Enter na entrada → `PanelViewModel.NavigateToAsync(path)` no painel ativo | Reutiliza navegação existente | n |
| VFS paths | Entradas armazenam path completo (`ftp://user@host/path`); `IFileSystemService` resolve | Transparente para hotlist | n |
| Grupos | Expansíveis/colapsáveis; entrada pode estar na raiz (sem grupo) ou em grupo | Igual MC original | n |
| Persistência | Carrega no startup; salva on-change (debounced 500ms) ou no fechamento do diálogo | Simples e confiável | n |
| Testes | Lógica (CRUD grupos/entradas, navegação, persistência) em xunit; UI por build-gate + UAT | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Hotlist com grupos e navegação ⭐ MVP

**User Story**: Como usuário, quero pressionar Ctrl+\ e ver minha hotlist organizada em grupos, para pular rapidamente para diretórios frequentes.

**Why P1**: Funcionalidade central da hotlist MC; atalho Ctrl+\ é icônico.

**Acceptance Criteria**:

1. WHEN the user presses Ctrl+\ THEN a hotlist window SHALL open showing a hierarchical tree of groups and entries.
2. WHEN the user double-clicks or presses Enter on an entry THEN the active panel SHALL navigate to that directory path (local or VFS).
3. WHEN the hotlist window opens THEN it SHALL load persisted entries from user config.
4. WHEN the user closes the hotlist window THEN any pending changes SHALL be auto-saved.

**Independent Test**: Ctrl+\ abre hotlist; duplo-clique em entrada navega painel; reiniciar app mantém entradas.

---

### P1: Adicionar/remover/editar entradas e grupos ⭐ MVP

**User Story**: Como usuário, quero adicionar o diretório atual à hotlist, criar grupos, renomear/mover/remover entradas, para organizar meus bookmarks.

**Why P1**: Gerenciamento da hotlist é uso diário.

**Acceptance Criteria**:

1. WHEN the user clicks "Add current directory" (or presses Ins) THEN a dialog SHALL prompt for entry name and target group (default: current panel directory path), and add it to the hotlist.
2. WHEN the user clicks "New group" THEN a dialog SHALL prompt for group name and create it at root or inside selected group.
3. WHEN the user selects an entry/group and clicks "Remove" (or presses Del) THEN a confirmation SHALL appear and on confirm the item SHALL be removed.
4. WHEN the user drags an entry to another group THEN the entry SHALL move to that group.
5. WHEN the user right-clicks an entry/group THEN a context menu SHALL offer Rename, Move, Remove, Copy path.

**Independent Test**: Add current dir → aparece na lista; New group → cria grupo; drag entry para grupo → move; Del + confirm → remove.

---

### P1: Persistência entre sessões ⭐ MVP

**User Story**: Como usuário, quero que minha hotlist sobreviva a reinícios do app, para não perder meus bookmarks.

**Why P1**: Sem persistência a hotlist é inútil.

**Acceptance Criteria**:

1. WHEN the user adds/removes/moves entries THEN the hotlist SHALL be saved to user config file (JSON) within 500ms (debounced) or on dialog close.
2. WHEN the application restarts THEN the hotlist SHALL load all groups/entries from config and display them identically.
3. IF the config file is missing/corrupted THEN the hotlist SHALL start empty without crashing.

**Independent Test**: Add entradas, fechar app, reabrir → entradas mantidas; corromper JSON → app abre com hotlist vazia.

---

### P2: Integração com menu e atalhos ⭐ MVP

**User Story**: Como usuário, quero acessar a hotlist via menu `Command > Directory hotlist` e atalho Ctrl+\, para descobrir e usar o recurso.

**Why P2**: Descoberta e consistência UI.

**Acceptance Criteria**:

1. THE `Command > Directory hotlist` menu item SHALL be enabled and SHALL open the hotlist window (same as Ctrl+\).
2. THE hotlist window SHALL have a function key toolbar (F1-F10) with labels: `Help`, `Add`, `Remove`, `Group`, `Enter`, `...`, `Quit` (F10).
3. WHEN the user presses F10 or Esc in the hotlist window THEN it SHALL close.

---

## Edge Cases

- IF the target directory of a hotlist entry no longer exists THEN navigation SHALL show an error in the panel (reusing existing inaccessible directory handling) and the entry SHALL remain in hotlist (user may fix path).
- IF the hotlist entry is a VFS path and the connection fails THEN the panel SHALL show connection error; entry remains in hotlist.
- IF the user tries to add a duplicate path (same path, same group) THEN the dialog SHALL warn and not add duplicate.
- IF the config directory is not writable THEN the hotlist SHALL work in-memory only with a warning banner.
- MAXIMUM entries per group: unlimited (bounded by memory); UI virtualizes if >1000.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| HOT-01 | P1: Hotlist UI + navegação | Specify | Pending |
| HOT-02 | P1: Hotlist UI + navegação | Specify | Pending |
| HOT-03 | P1: Hotlist UI + navegação | Specify | Pending |
| HOT-04 | P1: Hotlist UI + navegação | Specify | Pending |
| HOT-05 | P1: CRUD entradas/grupos | Specify | Pending |
| HOT-06 | P1: CRUD entradas/grupos | Specify | Pending |
| HOT-07 | P1: CRUD entradas/grupos | Specify | Pending |
| HOT-08 | P1: CRUD entradas/grupos | Specify | Pending |
| HOT-09 | P1: CRUD entradas/grupos | Specify | Pending |
| HOT-10 | P1: Persistência | Specify | Pending |
| HOT-11 | P1: Persistência | Specify | Pending |
| HOT-12 | P1: Persistência | Specify | Pending |
| HOT-13 | P2: Menu/Atalhos | Specify | Pending |
| HOT-14 | P2: Menu/Atalhos | Specify | Pending |
| HOT-15 | P2: Menu/Atalhos | Specify | Pending |

**ID format:** `HOT-NN` (Hotlist)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 15 total, 0 mapped to tasks, 15 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] Ctrl+\ abre hotlist com tree hierárquica; Enter/duplo-clique navega painel ativo.
- [ ] Add current dir, New group, New entry, Remove, drag-drop move, context menu funcionam.
- [ ] Persistência JSON em config do usuário; sobrevive a restart; JSON corrompido → vazio sem crash.
- [ ] Menu `Command > Directory hotlist` habilitado; toolbar F1-F10 no diálogo; F10/Esc fecha.
- [ ] Entradas VFS (`ftp://`, `sftp://`, `tar://`) funcionam igual a locais.
- [ ] Suite de testes existente (236) continua passando; novos testes: unit hotlist model/persistência, integração painel.
- [ ] Build com `-warnaserror` limpo.