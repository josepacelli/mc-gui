# Find File (Alt+F7) Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje não tem busca de arquivos. O Midnight Commander original possui um diálogo "Find file" (Alt+F7) extremamente poderoso que permite buscar arquivos por: nome (glob/regex, case-sensitive), conteúdo (texto/regex, case-sensitive, whole words, first hit), recursivo, seguir symlinks, ignorar ocultos, ignorar diretórios específicos, e todos charsets. Os resultados são mostrados em uma lista navegável com botões: View (F3), Edit (F4), Panelize (envia resultados para painel como lista virtual), Tree (mostra em árvore), Stop/Continue. Esta feature entrega o Find File no mc-gui, acessível via Alt+F7 e menu `Command > Find file`, com: diálogo de busca com todas as opções essenciais, execução assíncrona com progresso, lista de resultados clicável (abre no viewer/editor/painel), e ações Panelize/Tree.

## Goals

- [ ] Atalho Alt+F7 abre diálogo "Find file"; menu `Command > Find file` habilitado.
- [ ] Diálogo com campos: Start path (diretório inicial), File name (padrão glob/regex), Content (texto para buscar dentro dos arquivos).
- [ ] Opções de nome: Case sensitive, Glob/Regex toggle, Recursive, Follow symlinks, Skip hidden, All charsets.
- [ ] Opções de conteúdo: Case sensitive, Regex, First hit only, Whole words, All charsets.
- [ ] Ignore directories: lista de pastas separadas por `:` para pular (ex.: `.git:node_modules:build`).
- [ ] Botão "Start" inicia busca assíncrona; progress bar + contador de arquivos verificados + botão "Stop".
- [ ] Resultados em lista navegável: caminho, tamanho, data, permissões; duplo-clique/Enter abre no Viewer (F3) ou Editor (F4) conforme config.
- [ ] Botões na lista de resultados: `View` (F3), `Edit` (F4), `Panelize` (envia resultados para painel ativo como lista virtual navegável), `Tree` (abre Directory Tree filtrada), `Stop`/`Continue`.
- [ ] Busca roda em background (thread pool); UI responsiva; progresso atualizado em tempo real.
- [ ] Histórico de buscas recentes (path, pattern, content) persistido e sugerido via autocomplete nos campos.
- [ ] Integração VFS: busca funciona em paths `ftp://`, `sftp://`, `tar://` (apenas leitura).

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Busca por metadados (tamanho > X, data < Y, permissões) | MC tem via `find` externo; GUI pode adicionar depois |
| Substituição em massa (find & replace em arquivos) | Editor feature; Find file é só busca |
| Salvar/gerenciar perfis de busca nomeados | Nice-to-have; histórico simples cobre |
| Busca incremental "as you type" (sem botão Start) | Diálogo MC é modal com botão Start; manter paradigma |
| Indexação prévia (locate/mlocate) | Fora do escopo; busca é recursiva em tempo real |
| Filtro por tipo de arquivo (extensão) | Coberto por pattern no nome |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| UI do diálogo | Janela modal (`Window`) com abas/grupos: "File name", "Content", "Options", "Ignore dirs" | Organiza muitas opções; MC usa dialog único com checkboxes | n |
| Execução assíncrona | `Task.Run` + `IProgress<FindProgress>` + `CancellationToken`; thread pool dedicado | UI responsiva; progresso real | n |
| Resultados | `ObservableCollection<FindResult>` bindada a `DataGrid`/`ListView` virtualizada | Performance para milhares de resultados | n |
| Abertura de resultado | Duplo-clique/Enter → abre no Viewer (padrão) ou Editor (config); botões View/Edit explícitos | MC original | n |
| Panelize | Cria painel virtual ("Panelize") com resultados; painel mostra path, size, date; Enter no resultado abre viewer/editor | Feature MC original "Panelize" | n |
| Tree | Abre Directory Tree (se feature implementada) filtrada para mostrar apenas pastas dos resultados | Integração cross-feature | n |
| Cancelamento | `CancellationToken` passado para walker; para no próximo arquivo verificado | Responsivo | n |
| Persistência | Últimos 20 critérios de busca salvos em config; autocomplete nos campos | Conveniência | n |
| Testes | Unit: FindEngine (walker, filtros, macros); Integration: diálogo + progresso + resultados (mock FS); UAT: busca real | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Diálogo de busca com opções completas ⭐ MVP

**User Story**: Como usuário, quero pressionar Alt+F7 e configurar uma busca por nome e/ou conteúdo com todas as opções do MC, para encontrar arquivos precisamente.

**Why P1**: Interface central da feature; Alt+F7 é atalho icônico MC.

**Acceptance Criteria**:

1. WHEN the user presses Alt+F7 THEN a modal "Find file" window SHALL open with fields: Start path (pre-filled with active panel directory), File name pattern, Content pattern.
2. THE dialog SHALL have checkboxes for: Case sensitive (name), Glob/Regex (name), Recursive, Follow symlinks, Skip hidden, All charsets (name), Case sensitive (content), Regex (content), First hit, Whole words, All charsets (content), Ignore dirs (input text).
3. WHEN the user clicks "Start" THEN the search SHALL begin asynchronously; the button SHALL change to "Stop"; a progress bar SHALL show files scanned / matches found / current path.
4. WHEN the user clicks "Stop" THEN the search SHALL cancel gracefully at the next file boundary; results so far SHALL remain visible.
5. THE dialog SHALL remember the last used values (path, patterns, options) and pre-fill them on next open.

**Independent Test**: Alt+F7 → preenche "*.cs" + "TODO" + Recursive + Content case insensitive → Start → progress roda → Stop para → resultados listados.

---

### P1: Lista de resultados com ações ⭐ MVP

**User Story**: Como usuário, quero ver os resultados da busca em uma lista navegável e abrir/editar/panelize arquivos encontrados, para agir sobre eles imediatamente.

**Why P1**: Resultados sem ação são inúteis; MC original tem View/Edit/Panelize/Tree.

**Acceptance Criteria**:

1. WHEN the search finds matches THEN a results list SHALL appear below the search options (or in a tab) showing: full path, size, modified date, permissions.
2. WHEN the user double-clicks or presses Enter on a result THEN the file SHALL open in the Viewer (F3) by default (configurable to Editor).
3. WHEN the user clicks "View" button (or presses F3) on a selected result THEN the Viewer SHALL open for that file.
4. WHEN the user clicks "Edit" button (or presses F4) on a selected result THEN the Editor SHALL open for that file.
5. WHEN the user clicks "Panelize" button THEN the active panel SHALL switch to a "Panelized" mode showing only the search results as a virtual directory; Enter on result opens Viewer/Editor.
6. WHEN the user clicks "Tree" button THEN the Directory Tree panel SHALL open (if feature exists) filtered to show the directory hierarchy of the results.
7. THE results list SHALL support keyboard navigation (Up/Down, Enter, F3, F4) and multi-selection (Space/Insert).

**Independent Test**: Busca "TODO" em `~/src` → 50 resultados; Enter abre viewer; F4 abre editor; Panelize cria painel virtual com 50 entradas.

---

### P1: Execução assíncrona com progresso e cancelamento ⭐ MVP

**User Story**: Como usuário, quero que a busca rode em background sem travar a UI, com progresso visível e botão Stop, para buscar em árvores grandes sem frustração.

**Why P1**: Busca recursiva em `/home` pode levar minutos; UI congelada é inaceitável.

**Acceptance Criteria**:

1. WHEN "Start" is clicked THEN the search SHALL run on a background thread (not UI thread); the main window SHALL remain responsive.
2. THE progress indicator SHALL update in real-time: files scanned count, matches found count, current directory being scanned.
3. WHEN "Stop" is clicked THEN the search SHALL terminate within 1 second (cancellation token checked per file/directory).
4. IF the search completes (or is stopped) THEN the "Start" button SHALL be re-enabled and final counts SHALL be shown.

**Independent Test**: Busca em `~/Projects` (100k arquivos) → progress atualiza suavemente; Stop para em <1s; UI principal responsiva durante busca.

---

### P2: Histórico e autocomplete ⭐ MVP

**User Story**: Como usuário, quero que meus padrões de busca recentes sejam sugeridos, para repetir buscas comuns sem redigitar.

**Why P2**: Produtividade; MC original tem histórico compartilhado de busca.

**Acceptance Criteria**:

1. THE Start path, File name, and Content fields SHALL show autocomplete dropdown with last 20 used values (persisted in config).
2. WHEN the user selects a history item THEN the field SHALL be populated and other fields SHALL auto-fill if that history entry had them.
3. HISTORY SHALL be saved on dialog close or search start; loaded on dialog open.

---

## Edge Cases

- IF the start path is a VFS path (`ftp://`, `tar://`) THEN the search SHALL work recursively within that VFS (read-only).
- IF the content pattern is empty and file name pattern is empty THEN the "Start" button SHALL be disabled (at least one pattern required).
- IF the user searches for content in binary files THEN the search SHALL skip binary detection (heuristic: null bytes in first 8KB) or search anyway with warning.
- IF the search encounters permission denied THEN it SHALL log error and continue; errors aggregated in a "Errors" expander in results.
- IF the results list exceeds 10,000 entries THEN virtualization SHALL keep UI responsive; "Panelize" still works.
- IF the user closes the Find dialog while search is running THEN the search SHALL continue in background with a toast notification on completion; dialog can be reopened to see results.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| FND-01 | P1: Diálogo completo | Specify | Pending |
| FND-02 | P1: Diálogo completo | Specify | Pending |
| FND-03 | P1: Diálogo completo | Specify | Pending |
| FND-04 | P1: Diálogo completo | Specify | Pending |
| FND-05 | P1: Diálogo completo | Specify | Pending |
| FND-06 | P1: Resultados + ações | Specify | Pending |
| FND-07 | P1: Resultados + ações | Specify | Pending |
| FND-08 | P1: Resultados + ações | Specify | Pending |
| FND-09 | P1: Resultados + ações | Specify | Pending |
| FND-10 | P1: Resultados + ações | Specify | Pending |
| FND-11 | P1: Resultados + ações | Specify | Pending |
| FND-12 | P1: Assíncrono + progresso | Specify | Pending |
| FND-13 | P1: Assíncrono + progresso | Specify | Pending |
| FND-14 | P1: Assíncrono + progresso | Specify | Pending |
| FND-15 | P1: Assíncrono + progresso | Specify | Pending |
| FND-16 | P2: Histórico | Specify | Pending |
| FND-17 | P2: Histórico | Specify | Pending |
| FND-18 | P2: Histórico | Specify | Pending |

**ID format:** `FND-NN` (Find File)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 18 total, 0 mapped to tasks, 18 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] Alt+F7 abre diálogo completo com todas as opções MC; Start/Stop funcionam; progresso real-time.
- [ ] Resultados em lista navegável; Enter/F3 View, F4 Edit, Panelize, Tree funcionam.
- [ ] Busca assíncrona: UI responsiva; progresso atualiza; Stop cancela em <1s.
- [ ] Histórico de 20 buscas com autocomplete persiste entre sessões.
- [ ] Busca funciona em VFS (ftp, sftp, tar) read-only.
- [ ] Menu `Command > Find file` habilitado; atalho Alt+F7 funcional.
- [ ] Suite de testes existente (236) continua passando; novos testes: unit FindEngine, integração diálogo.
- [ ] Build com `-warnaserror` limpo.