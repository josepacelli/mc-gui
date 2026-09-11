# Diff Viewer Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje não tem visualizador de diferenças (diff). O Midnight Commander original possui um diff viewer (`Command > Compare files`, `Command > Compare directories`) que mostra diferenças lado a lado (two-pane) ou unificado, com destaque de cores para linhas adicionadas/removidas/modificadas, navegação por diferenças (próxima/anterior), e opções: ignorar espaços em branco, ignorar case, mostrar contexto. O diff viewer também suporta edição direta (aplicar mudança do lado esquerdo para direito ou vice-versa). Esta feature entrega o Diff Viewer no mc-gui: diálogo/janela para comparar dois arquivos ou dois diretórios, com visualização side-by-side colorida, navegação por hunks, opções de diff, e integração com Editor (F4) para editar e resolver conflitos.

## Goals

- [ ] Menu `Command > Compare files` habilitado; atalho (ex.: `Ctrl+D` ou `F9` > Command > Compare files) abre diálogo de diff de arquivos.
- [ ] Menu `Command > Compare directories` habilitado; abre diálogo de diff de diretórios (lista arquivos iguais/diferentes/novos/ausentes).
- [ ] Janela de diff de arquivos: visualização side-by-side (dois painéis sincronizados verticalmente) com linhas coloridas: verde (adicionado), vermelho (removido), amarelo (modificado), cinza (igual).
- [ ] Navegação: `F7`/`Shift+F7` (próxima/anterior diferença), `F6`/`Shift+F6` (próxima/anterior conflito), setas/PageUp/PageDown scroll sincronizado.
- [ ] Opções de diff (checkboxes/toolbar): Ignore whitespace, Ignore case, Show context lines (número), Unified vs Side-by-side toggle.
- [ ] Diff de diretórios: lista estilo "Compare directories" do MC — colunas: Name, Size (left), Size (right), Status (Equal/Different/Left only/Right only); duplo-clique em "Different" abre file diff; "Equal" abre viewer; botões: `Copy left→right`, `Copy right→left`, `Sync`.
- [ ] Integração com Editor (F4): botão "Edit left"/"Edit right" abre arquivo no Editor; após save, diff atualiza automaticamente.
- [ ] Suporte a VFS: diff funciona com paths `ftp://`, `sftp://`, `tar://` (download temp para diff).
- [ ] Algoritmo de diff: Myers O(ND) ou biblioteca .NET (`DiffPlex`, `Microsoft.Diff`); output unificado e side-by-side.

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Merge de 3 vias (3-way merge) | Complexidade; feature futura para resolução de conflitos git |
| Integração com Git (diff staged/unstaged, blame) | Feature separada (Git integration) |
| Diff de imagens/binários | Fora do escopo textual |
| Patch generation (export .patch) | Nice-to-have; `git diff` cobre |
| Syntax highlighting dentro do diff | Side-by-side usa monospace; highlighting opcional futuro |
| Word-level diff (intra-line) | Line-level é padrão MC; word-level depois |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Biblioteca diff | `DiffPlex` (NuGet, MIT) — suporta side-by-side, inline, hunks, Myers | Madura, .NET nativa, zero deps nativas | n |
| UI arquivo | Janela modal (`Window`) com `Grid` 2 colunas + toolbar; cada lado = `TextBlock`/`RichTextBlock` virtualizado | Side-by-side nativo | n |
| UI diretório | Janela modal com `DataGrid` virtualizada; colunas: Name, Size L, Size R, Status, Actions | Lista navegável | n |
| Cores | Verde `#4CAF50` (add), Vermelho `#F44336` (del), Âmbar `#FFC107` (mod), Cinza `#9E9E9E` (eq); respeita tema Light/Dark via `DynamicResource` | Consistente com tema mc-gui | n |
| Scroll sync | Dois `ScrollViewer` com `ScrollChanged` event sync vertical offset | Padrão side-by-side | n |
| Navegação hunks | Lista de hunks (diff chunks) no sidebar ou toolbar dropdown; F7 = próximo hunk | MC original | n |
| Editor integration | Botão "Edit left/right" → `EditorService.OpenFile(path, line)`; `EditorService.FileSaved` event → re-diff | Reutiliza Editor feature | n |
| VFS diff | Baixa arquivos remotos para temp local (`Path.GetTempFileName`); diff local; cleanup on close | Simples, reutiliza VFS read | n |
| Testes | Unit: DiffEngine (algo, hunks, options); Integration: file diff window, dir diff window; UAT: cores, nav, edit | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Diff de arquivos side-by-side ⭐ MVP

**User Story**: Como usuário, quero selecionar dois arquivos e pressionar Compare files para ver diferenças lado a lado com cores, navegar por mudanças, e editar se necessário.

**Why P1**: Diff é ferramenta essencial para desenvolvedores/admins; MC original tem.

**Acceptance Criteria**:

1. WHEN the user selects two files (one in each panel, or via dialog) and activates `Command > Compare files` THEN a diff window SHALL open showing side-by-side comparison.
2. THE left pane SHALL show file A content; right pane file B; lines color-coded: green background (added in B), red background (removed in B), amber background (changed), light gray (unchanged).
3. VERTICAL scroll SHALL be synchronized between panes; horizontal scroll independent.
4. WHEN the user presses F7 (Next diff) THEN the view SHALL jump to the next hunk with changes (added/removed/changed); Shift+F7 SHALL go to previous.
5. TOOLBAR SHALL have options: Ignore whitespace (checkbox), Ignore case (checkbox), Context lines (numeric input 3-10), Side-by-side/Unified toggle.
6. WHEN the user clicks "Edit left" or "Edit right" THEN the Editor (F4) SHALL open that file at the corresponding line; after saving in Editor, the diff SHALL auto-refresh.

**Independent Test**: Selecionar `file1.cs` no painel esquerdo, `file2.cs` no direito → Compare files → side-by-side com cores; F7 navega hunks; Edit left → editor abre; save → diff atualiza.

---

### P1: Diff de diretórios ⭐ MVP

**User Story**: Como usuário, quero comparar dois diretórios e ver quais arquivos são iguais, diferentes, só à esquerda, só à direita, e sincronizar.

**Why P1**: Directory compare é feature clássica do MC; essencial para sync/backup.

**Acceptance Criteria**:

1. WHEN the user activates `Command > Compare directories` (with two panels showing directories) THEN a directory diff window SHALL open with a grid: Name, Size (left), Size (right), Modified (left), Modified (right), Status.
2. STATUS values: `Equal` (green), `Different` (amber), `Left only` (blue), `Right only` (orange), `Error` (red).
3. WHEN the user double-clicks a `Different` row THEN file diff window SHALL open for that pair.
4. WHEN the user double-clicks an `Equal` row THEN Viewer (F3) SHALL open for that file.
5. TOOLBAR buttons: `Copy left→right` (copies selected Left only/Different to right), `Copy right→left`, `Sync` (makes right match left: copies missing, updates different, deletes extra on right — with confirmation).
6. CONTEXT MENU on row: View, Edit left, Edit right, Copy L→R, Copy R→L, Exclude from sync.

**Independent Test**: Compare `~/src` vs `~/backup` → lista com status; Different → file diff; Left only → Copy L→R copia; Sync → painel direito espelha esquerdo.

---

### P2: Opções avançadas e persistência ⭐ MVP

**User Story**: Como usuário, quero configurar opções de diff (ignore whitespace, context lines) e tê-las persistidas, para diffs consistentes.

**Why P2**: Preferências pessoais de diff variam; persistência evita reconfigurar.

**Acceptance Criteria**:

1. THE diff options (Ignore whitespace, Ignore case, Context lines, Side-by-side/Unified) SHALL be persisted in user config and restored on next open.
2. THE diff window SHALL remember its size, position, and splitter position.
3. UNIFIED mode SHALL show single pane with `+/-` prefix lines, color-coded; navigation F7 still works.
4. KEYBOARD shortcuts: F7/Shift+F7 (next/prev diff), F6/Shift+F6 (next/prev conflict), Ctrl+S (save diff as patch — optional), Esc (close).

---

## Edge Cases

- IF the two files are identical THEN diff window SHALL show "Files are identical" message with option to close.
- IF one file is binary (contains null bytes) THEN diff SHALL show "Binary files differ" with option to open in hex viewer (F3).
- IF a file is very large (>10MB) THEN diff SHALL run asynchronously with progress indicator; UI shows "Computing diff...".
- IF the user edits a file in Editor and saves THEN diff SHALL re-compute only affected region (incremental) or full re-diff (simpler).
- IF Compare directories is run on VFS paths (ftp://) THEN it SHALL work by downloading file lists and comparing metadata; file diff downloads temp files.
- MAXIMUM file size for diff: 50MB (configurable); larger files show warning and offer to diff first N lines only.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| DIF-01 | P1: Diff arquivos side-by-side | Specify | Pending |
| DIF-02 | P1: Diff arquivos side-by-side | Specify | Pending |
| DIF-03 | P1: Diff arquivos side-by-side | Specify | Pending |
| DIF-04 | P1: Diff arquivos side-by-side | Specify | Pending |
| DIF-05 | P1: Diff arquivos side-by-side | Specify | Pending |
| DIF-06 | P1: Diff arquivos side-by-side | Specify | Pending |
| DIF-07 | P1: Diff diretórios | Specify | Pending |
| DIF-08 | P1: Diff diretórios | Specify | Pending |
| DIF-09 | P1: Diff diretórios | Specify | Pending |
| DIF-10 | P1: Diff diretórios | Specify | Pending |
| DIF-11 | P1: Diff diretórios | Specify | Pending |
| DIF-12 | P1: Diff diretórios | Specify | Pending |
| DIF-13 | P2: Opções avançadas | Specify | Pending |
| DIF-14 | P2: Opções avançadas | Specify | Pending |
| DIF-15 | P2: Opções avançadas | Specify | Pending |
| DIF-16 | P2: Opções avançadas | Specify | Pending |

**ID format:** `DIF-NN` (Diff)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 16 total, 0 mapped to tasks, 16 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] `Command > Compare files` abre diff side-by-side colorido; F7 navega hunks; scroll sync; Edit left/right abre Editor.
- [ ] `Command > Compare directories` abre grid com status; Double-click Different → file diff; Equal → viewer; Copy L→R/R→L, Sync funcionam.
- [ ] Opções (ignore whitespace, case, context, unified/side-by-side) funcionam e persistem.
- [ ] Integração VFS: diff funciona com ftp/sftp/tar paths.
- [ ] Menus `Command > Compare files` / `Compare directories` habilitados.
- [ ] Suite de testes existente (236) continua passando; novos testes: unit DiffEngine, integração diff windows.
- [ ] Build com `-warnaserror` limpo.