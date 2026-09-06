# Directory Tree Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje não tem visualização de árvore de diretórios. O Midnight Commander original possui uma árvore de diretórios (Command > Directory tree, ou `Ctrl+T` em algumas versões) que mostra a hierarquia do filesystem em painel lateral ou janela separada, permitindo navegação rápida: expandir/colapsar pastas, selecionar diretório para definir como painel ativo, e modo "xtree" onde o painel oposto segue a seleção na árvore. Esta feature entrega a Directory Tree no mc-gui, acessível via menu `Command > Directory tree` e atalho (ex.: `Ctrl+T`), com: painel lateral redimensionável (dock à esquerda), árvore hierárquica expansível, navegação por teclado/mouse, sincronização com painel ativo (clique na árvore → painel navega), e modo "Follow panel" (tree segue painel) e "Lead panel" (painel segue tree).

## Goals

- [ ] Menu `Command > Directory tree` habilitado; atalho `Ctrl+T` abre/fecha painel da árvore.
- [ ] Painel da árvore (dock à esquerda, redimensionável) mostra hierarquia de diretórios a partir da raiz (`/`) ou home do usuário.
- [ ] Pastas expansíveis/colapsáveis (seta `▶`/`▼` ou `+`/`-`); estado de expansão persistido entre sessões.
- [ ] Seleção na árvore (clique ou Enter) define o diretório no painel ativo (ou painel oposto se configurado).
- [ ] Modo "Follow panel" (padrão): árvore destaca e expande caminho do painel ativo automaticamente.
- [ ] Modo "Lead panel" (xtree): seleção na árvore navega painel oposto (painel ativo fica fixo).
- [ ] Teclas de navegação: setas (expandir/colapsar/navegar), Enter (selecionar), Space (toggle expand), Ctrl+T (toggle painel).
- [ ] Contexto VFS: árvore mostra apenas filesystem local no MVP; VFS (ftp, tar) em fase futura.
- [ ] Busca incremental na árvore (digitar letras filtra/posiciona no nó correspondente).
- [ ] Menu de contexto (botão direito): New folder, Delete, Refresh, Copy path, Open in new panel.

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Árvore para VFS (ftp, sftp, tar) | Requer integração com plugins VFS; fase futura |
| Múltiplas raízes (ex.: mostrar `/` e `/home` e `/mnt` como raízes separadas) | MC original tem raiz única; pode ser config futuro |
| Drag-and-drop de arquivos do painel para árvore (mover/copiar) | Feature futura; requer integração copy/move |
| Sincronização de expansão entre instâncias | Persistência local é suficiente |
| Filtro por tipo (apenas pastas, ocultar ocultas) | MC não filtra; mostra tudo |
| Mini-info (tamanho, permissões) na árvore | Árvore é só navegação; painel mostra detalhes |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Layout | Painel lateral esquerdo (dock), redimensionável via splitter; pode ser ocultado/mostrado | Padrão GUI modernos (VS Code, IDEs); MC terminal usa painel lateral | n |
| Componente UI | `TreeView` / `TreeDataGrid` Avalonia com `TreeDataGridSource` hierárquico | Nativo, virtualização, expansão preguiçosa | n |
| Carregamento preguiçoso | Carrega filhos só ao expandir nó (`IFileSystemService.ListDirectory` assíncrono) | Performance em filesystems grandes | n |
| Estado de expansão | Persistido em config (`~/.config/mc-gui/tree-state.json`) como lista de paths expandidos | Sobrevive a restart | n |
| Raiz inicial | Home do usuário (`~`) em vez de `/` (mais prático); opção para `/` | Usuário comum não navega em `/` | n |
| Sincronização painel↔árvore | Evento `PanelViewModel.CurrentDirectoryChanged` → árvore seleciona/expande path; `TreeView.SelectionChanged` → painel navega (se Lead mode) | Reativo, desacoplado | n |
| Lead/Follow mode | Toggle no menu de contexto da árvore ou toolbar; Follow = default (MC `xtree_mode=false`) | MC original | n |
| Atalho | `Ctrl+T` (não usado atualmente); `F2` menu > Directory tree | `Ctrl+T` livre no KeyGestureMap | n |
| Testes | Unit: TreeModel (carregamento, expansão, seleção, persistência); UAT: UI, sync painel | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Painel de árvore lateral com navegação ⭐ MVP

**User Story**: Como usuário, quero pressionar Ctrl+T e ver uma árvore de diretórios à esquerda, clicar em uma pasta para navegar o painel principal para lá, para explorar a hierarquia rapidamente.

**Why P1**: Funcionalidade central da directory tree; substitui navegação repetitiva por Enter/Backspace.

**Acceptance Criteria**:

1. WHEN the user presses Ctrl+T THEN a tree panel SHALL appear docked on the left side of the main window, showing the directory hierarchy starting from the user's home directory.
2. WHEN the user clicks a folder node in the tree THEN the active panel SHALL navigate to that directory path.
3. WHEN the user presses the expand/collapse toggle (▶/▼ or Space) on a folder THEN the node SHALL expand to show children or collapse to hide them.
4. WHEN the user navigates the active panel by other means (Enter, Backspace, path input) THEN the tree SHALL auto-select and expand to show the new current directory (Follow mode).
5. WHEN the user presses Ctrl+T again THEN the tree panel SHALL hide (state preserved for next toggle).

**Independent Test**: Ctrl+T abre árvore; clica pasta → painel navega; Enter no painel → árvore acompanha; Ctrl+T esconde.

---

### P1: Expansão preguiçosa e persistência ⭐ MVP

**User Story**: Como usuário, quero que a árvore carregue pastas só quando eu expandir, e lembre quais pastas deixei expandidas, para performance e conveniência.

**Why P1**: Filesystems grandes (ex.: `/usr`, `/var`) têm milhares de pastas; carregar tudo trava UI.

**Acceptance Criteria**:

1. WHEN the tree first loads THEN only the root (home) and its immediate children SHALL be loaded; deeper levels SHALL load on-demand when parent is expanded.
2. WHEN the user expands a folder THEN the system SHALL call `IFileSystemService.ListDirectory` for that path and populate children asynchronously (with loading indicator).
3. THE expansion state of folders SHALL be persisted to user config and restored on app restart.
4. IF a folder has no subdirectories THEN its expand toggle SHALL be hidden/disabled.

**Independent Test**: Expandir `~/Projects` → carrega subpastas; reiniciar app → `~/Projects` ainda expandido.

---

### P1: Modo Lead panel (xtree) ⭐ MVP

**User Story**: Como usuário, quero alternar para modo "Lead panel" onde a árvore controla o painel oposto, mantendo o painel ativo fixo, para comparar/copiar entre duas pastas da árvore.

**Why P1**: Feature clássica do MC (`xtree_mode`); diferencial para workflows de comparação.

**Acceptance Criteria**:

1. THE tree panel SHALL have a toggle/menu item "Lead panel" (ou "xtree mode") to switch between Follow (default) and Lead modes.
2. IN Follow mode: panel navigation drives tree selection (tree follows panel).
3. IN Lead mode: tree selection drives the *inactive* panel navigation (panel follows tree); active panel remains unchanged.
4. THE current mode SHALL be indicated in the tree panel header (ex.: `[Follow]` / `[Lead]`).
5. MODE SHALL persist across sessions.

**Independent Test**: Ativar Lead mode; clicar pastas diferentes na árvore → painel inativo alterna; painel ativo fixo.

---

### P2: Busca incremental e menu de contexto ⭐ MVP

**User Story**: Como usuário, quero digitar para filtrar a árvore e usar botão direito para ações rápidas (nova pasta, apagar, copiar caminho).

**Why P2**: Produtividade; busca evita navegar manualmente em árvores grandes.

**Acceptance Criteria**:

1. WHEN the tree panel has focus and the user types printable characters THEN the tree SHALL filter to show only nodes matching the typed substring (case-insensitive, anywhere in path), highlighting matches.
2. WHEN the user presses Escape or clears the filter THEN the tree SHALL restore full view.
3. WHEN the user right-clicks a folder node THEN a context menu SHALL appear with: `New folder`, `Delete`, `Refresh`, `Copy path`, `Open in active panel`, `Open in inactive panel`.
4. `New folder` SHALL prompt for name and create via `IFileSystemService.CreateDirectory`.
5. `Delete` SHALL confirm and delete via `IFileSystemService` (trash if available).
6. `Copy path` SHALL copy full path to clipboard.

---

## Edge Cases

- IF the user expands a folder with 1000+ subdirectories THEN the tree SHALL virtualize rendering (Avalonia `TreeDataGrid` handles this) and show a loading spinner.
- IF a directory becomes inaccessible (permission denied) THEN the node SHALL show an error icon and tooltip; expanding SHALL show error message.
- IF the tree is in Lead mode and the user closes the inactive panel THEN Lead mode SHALL automatically switch to Follow (no target panel).
- IF the user types in the tree but focus is in the panel THEN the tree SHALL NOT filter (focus-aware).
- SYMLINKS to directories: SHALL be displayed as folders with link indicator; expanding follows the link (or shows target).
- MAXIMUM tree depth: unlimited (bounded by filesystem); UI virtualizes.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| DTR-01 | P1: Árvore lateral + navegação | Specify | Pending |
| DTR-02 | P1: Árvore lateral + navegação | Specify | Pending |
| DTR-03 | P1: Árvore lateral + navegação | Specify | Pending |
| DTR-04 | P1: Árvore lateral + navegação | Specify | Pending |
| DTR-05 | P1: Árvore lateral + navegação | Specify | Pending |
| DTR-06 | P1: Expansão preguiçosa + persistência | Specify | Pending |
| DTR-07 | P1: Expansão preguiçosa + persistência | Specify | Pending |
| DTR-08 | P1: Expansão preguiçosa + persistência | Specify | Pending |
| DTR-09 | P1: Expansão preguiçosa + persistência | Specify | Pending |
| DTR-10 | P1: Lead panel (xtree) | Specify | Pending |
| DTR-11 | P1: Lead panel (xtree) | Specify | Pending |
| DTR-12 | P1: Lead panel (xtree) | Specify | Pending |
| DTR-13 | P1: Lead panel (xtree) | Specify | Pending |
| DTR-14 | P1: Lead panel (xtree) | Specify | Pending |
| DTR-15 | P2: Busca + contexto | Specify | Pending |
| DTR-16 | P2: Busca + contexto | Specify | Pending |
| DTR-17 | P2: Busca + contexto | Specify | Pending |
| DTR-18 | P2: Busca + contexto | Specify | Pending |
| DTR-19 | P2: Busca + contexto | Specify | Pending |
| DTR-20 | P2: Busca + contexto | Specify | Pending |

**ID format:** `DTR-NN` (Directory Tree)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 20 total, 0 mapped to tasks, 20 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] Ctrl+T abre/fecha painel árvore lateral; clique na árvore navega painel ativo.
- [ ] Expansão preguiçosa assíncrona; estado de expansão persiste entre restarts.
- [ ] Follow mode (default): painel navega → árvore acompanha; Lead mode: árvore navega painel oposto.
- [ ] Busca incremental digita→filtra; Escape limpa; menu contexto: New folder, Delete, Refresh, Copy path.
- [ ] Menu `Command > Directory tree` habilitado; atalho Ctrl+T funcional.
- [ ] Suite de testes existente (236) continua passando; novos testes: unit TreeModel, integração painel.
- [ ] Build com `-warnaserror` limpo.