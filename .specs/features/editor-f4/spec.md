# Editor (F4) Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje não tem editor de texto interno. O Midnight Commander original possui um editor completo (F4) acessível via tecla F4 ou menu `File > Edit` que suporta: edição de texto com syntax highlighting, macros graváveis/reproduzíveis, verificação ortográfica (aspell), completamento de código, tags (etags/cscope), undo/redo ilimitado, múltiplos arquivos (buffer stack), busca/substituição com regex, blocos verticais/horizontais, auto-indent, word wrap, salvamento de posição, e integração com VFS. Esta feature (fatia A) entrega um editor GUI funcional no mc-gui, acessível via F4 no painel ativo e item de menu `File > Edit`, com as funcionalidades essenciais: edição de texto, syntax highlighting, undo/redo, busca/substituição, múltiplos arquivos (abas), e teclas de atalho estilo MC. Macros, spell check, tags, e blocos verticais ficam para fase futura.

## Goals

- [ ] Pressionar F4 em um arquivo abre o editor em janela com o conteúdo do arquivo carregado.
- [ ] Editor exibe texto com syntax highlighting para linguagens comuns (C, C#, Python, JSON, XML, Shell, Markdown, etc.) via biblioteca padrão (ex.: AvaloniaEdit).
- [ ] Undo/redo ilimitado (Ctrl+Z / Ctrl+Y) funcional.
- [ ] Busca (Ctrl+F) e substituição (Ctrl+H) com suporte a regex, case-sensitive/insensitive, whole word.
- [ ] Múltiplos arquivos abertos em abas; Ctrl+Tab alterna; Ctrl+W fecha aba.
- [ ] Auto-indent ao pressionar Enter; Tab insere tabs ou espaços conforme configuração.
- [ ] Salvamento: Ctrl+S salva; Ctrl+Shift+S "Save As"; prompt se arquivo modificado ao fechar.
- [ ] Teclas de navegação MC: setas, Home/End, PgUp/PgDn, Ctrl+Home/End (início/fim arquivo), Ctrl+setas (palavra).
- [ ] Seleção com Shift+setas; Ctrl+A seleciona tudo; Ctrl+C/X/V copiar/cortar/colar.
- [ ] Janela do editor tem toolbar F1-F10 contextual: Help, Save, Replace, Search, Macro, Block, etc.
- [ ] Fechar editor (Esc, F10, botão fechar) retorna ao painel; prompt se alterações não salvas.
- [ ] Item de menu `File > Edit` (F4) habilitado no menubar.
- [ ] Integração com `IFileSystemService` para carregar/salvar (suporta VFS futuro).

## Out of Scope

Explicitamente excluído desta feature (fatia B separada).

| Feature | Motivo |
| --- | --- |
| Macros graváveis/reproduzíveis (Ctrl+R, Ctrl+P) | Complexidade de gravação/reprodução de teclas; feature futura |
| Verificação ortográfica (aspell/hunspell) | Dependência externa; feature futura |
| Tags/etags/cscope (navegação de símbolos) | Exige parsing de linguagem; feature futura |
| Completamento de código (Ctrl+Space) | Exige LSP/language server; feature futura |
| Blocos verticais (Ctrl+V) | Modo de seleção especial; feature futura |
| Integração com diff/merge | Feature separada (diff viewer) |
| Configuração avançada de syntax highlighting | Usa definições padrão do AvaloniaEdit; customização depois |
| Encoding detection/fallback avançado | Editor usa UTF-8; fallback básico |
| Templates/snippets | Feature futura |
| Integração com terminal/subshell | Fora do escopo do editor |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Componente de edição | `AvaloniaEdit` (TextEditor) — biblioteca madura, syntax highlighting built-in, undo/redo, busca/replace, abas via `TabControl` | Evita reescrever editor do zero; padrão no ecossistema Avalonia | n |
| Syntax highlighting | Definições `.xshd` do AvaloniaEdit para linguagens comuns; carregadas dinamicamente | Suficiente para MVP; customização depois | n |
| Abas | `TabControl` com `TextEditor` por aba; cada aba tem seu próprio estado (arquivo, cursor, modificações) | Padrão GUI moderno | n |
| Encoding | UTF-8 com BOM detection; fallback Latin-1 | Simplicidade; MC original tem `str_cnv_from_term` | n |
| Arquivos grandes (>10MB) | Carregamento assíncrono com indicador; virtualização de linhas via AvaloniaEdit | Evita freeze UI | n |
| Toolbar F-keys | Reutiliza padrão `PanelView` (botões F1-F10) com labels do editor MC | Consistência visual | n |
| Teclas de atalho | Mapeamento próximo do MC: F2=Save, F3=Find, F4=Replace, F5=Macro, F6=Block, F7=Spell, F8=Config, F9=Menu, F10=Quit | Familiaridade para usuários MC | n |
| VFS integration | Editor recebe `FileEntry` e usa `IFileSystemService` para read/write stream | Abstração de SO mantida | n |
| Testes | Lógica (carregamento, syntax, undo, busca, abas) em xunit; renderização por build-gate + UAT | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Edição de texto com syntax highlighting ⭐ MVP

**User Story**: Como usuário, quero pressionar F4 em um arquivo e editá-lo com syntax highlighting, para modificar código/config sem sair do gerenciador.

**Why P1**: Funcionalidade central do F4 no MC; base para demais features.

**Acceptance Criteria**:

1. WHEN the user presses F4 on a selected file entry in the active panel THEN the system SHALL open an editor window with the file's content loaded and syntax highlighting applied based on file extension.
2. WHEN the user types in the editor THEN the text SHALL be inserted at the cursor position with auto-indent on Enter.
3. WHEN the user presses Ctrl+S THEN the file SHALL be saved to disk (via `IFileSystemService`) and the modified flag SHALL be cleared.
4. WHEN the user attempts to close the editor/tab with unsaved changes THEN the system SHALL prompt to save/discard/cancel.

**Independent Test**: Selecionar um `.cs`/`.py`/`.json`, F4 abre editor com highlighting; digitar texto, Ctrl+S salva; fechar aba sem salvar → prompt.

---

### P1: Undo/Redo ilimitado ⭐ MVP

**User Story**: Como usuário, quero desfazer/refazer alterações (Ctrl+Z / Ctrl+Y) sem limite, para experimentar edições sem medo.

**Why P1**: Expectativa básica de qualquer editor moderno; MC original tem undo ilimitado.

**Acceptance Criteria**:

1. WHEN the user presses Ctrl+Z THEN the last edit operation SHALL be undone, restoring previous text and cursor position.
2. WHEN the user presses Ctrl+Y (or Ctrl+Shift+Z) THEN the last undone operation SHALL be redone.
3. THE undo stack SHALL persist across multiple edits and SHALL NOT have a hard limit (bounded only by memory).
4. WHEN the file is saved THEN the undo stack SHALL be preserved (MC behavior: save doesn't clear undo).

**Independent Test**: Digitar "abc", Ctrl+Z → vazio; digitar "def", Ctrl+Z → "abc"; Ctrl+Y → "abcdef"; salvar, Ctrl+Z ainda funciona.

---

### P1: Busca e substituição com regex ⭐ MVP

**User Story**: Como usuário, quero buscar (Ctrl+F) e substituir (Ctrl+H) com regex, case-sensitive, whole word, para refatorar código rapidamente.

**Why P1**: Busca/substituição é essencial para edição de código; MC original tem busca poderosa.

**Acceptance Criteria**:

1. WHEN the user presses Ctrl+F THEN a search panel SHALL appear with input, regex toggle, case-sensitive toggle, whole-word toggle, and next/previous buttons.
2. WHEN the user types a pattern with regex enabled THEN matches SHALL be highlighted in the editor and the first match SHALL be selected.
3. WHEN the user presses Enter/F3 in search panel THEN the editor SHALL jump to the next match; Shift+Enter/Shift+F3 SHALL jump to previous.
4. WHEN the user presses Ctrl+H THEN a replace panel SHALL appear with replace input and "Replace"/"Replace All" buttons.
5. WHEN the user clicks "Replace All" THEN all matches in the current file SHALL be replaced and the count SHALL be reported.

**Independent Test**: Abrir arquivo com múltiplas ocorrências de "foo", Ctrl+F "foo.*bar" regex → highlights; Ctrl+H "foo"→"baz" Replace All → todas substituídas.

---

### P1: Múltiplos arquivos (abas) ⭐ MVP

**User Story**: Como usuário, quero editar múltiplos arquivos simultaneamente em abas, alternando com Ctrl+Tab, para trabalhar em vários arquivos sem reabrir.

**Why P1**: Editor MC original suporta stack de arquivos; abas é o equivalente GUI natural.

**Acceptance Criteria**:

1. WHEN the user presses F4 on a second file while editor is open THEN a new tab SHALL open with that file's content.
2. WHEN the user presses Ctrl+Tab THEN focus SHALL move to the next tab (cyclic); Ctrl+Shift+Tab SHALL move to previous.
3. WHEN the user presses Ctrl+W or clicks the tab close button THEN the tab SHALL close (prompt if unsaved).
4. THE tab header SHALL show the file name with a modified indicator (*) when dirty.

**Independent Test**: F4 em arquivo1, F4 em arquivo2 → 2 abas; Ctrl+Tab alterna; fechar aba2 → volta para aba1.

---

### P2: Integração com menubar e toolbar F-keys ⭐ MVP

**User Story**: Como usuário, quero acessar o editor via menu `File > Edit` (F4) e ver a toolbar F1-F10 contextual, para operar consistente com o mc-gui.

**Why P2**: Integração UI completa; menubar já tem item `Edit` desabilitado — agora habilita.

**Acceptance Criteria**:

1. THE `File > Edit` menu item SHALL be enabled and SHALL open the editor for the currently selected file in the active panel (same as F4 key).
2. THE editor window SHALL display a function key toolbar (F1-F10) with labels matching MC editor buttonbar: `Help`, `Save`, `Replace`, `Search`, `Macro`, `Block`, `Spell`, `Config`, `Menu`, `Quit`.
3. WHEN the user presses F2 in the editor THEN the file SHALL be saved (same as Ctrl+S).
4. WHEN the user presses F10 in the editor THEN the editor SHALL prompt to close (same as Esc/close button).

---

### P3: Configurações básicas do editor

**User Story**: Como usuário, quero configurar tabs vs espaços, tamanho do tab, word wrap, e mostrar whitespace, para adaptar o editor ao meu estilo.

**Why P3**: Configurações básicas esperadas; MC original tem `edit_options` extensivo.

**Acceptance Criteria**:

1. THE editor SHALL have a settings dialog (F8/Config) with options: tab width (default 4), insert spaces instead of tabs (default true), word wrap (default off), show whitespace (tabs/spaces/EOL), show line numbers (default on).
2. WHEN the user changes tab width THEN existing tabs SHALL be visually updated (spaces mode re-indents on edit).
3. WHEN the user toggles word wrap THEN the editor SHALL reflow text immediately.
4. SETTINGS SHALL persist across sessions (stored in user config).

---

## Edge Cases

- IF the selected entry is a directory THEN F4/Edit SHALL do nothing (MC original doesn't edit dirs).
- IF the file is read-only THEN the editor SHALL open in read-only mode with a visual indicator; save attempts SHALL prompt for "Save As".
- IF the file is larger than 50MB THEN the editor SHALL load asynchronously with progress indicator and may disable syntax highlighting for performance.
- IF the file encoding is not UTF-8 THEN the editor SHALL attempt detection and show a warning bar with "Reopen with encoding..." option.
- WHEN the user opens the same file in two tabs THEN the second tab SHALL focus the existing tab instead of duplicating.
- IF the underlying file is modified externally THEN the editor SHALL detect on focus and prompt to reload.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| EDT-01 | P1: Edição + syntax | Specify | Pending |
| EDT-02 | P1: Edição + syntax | Specify | Pending |
| EDT-03 | P1: Edição + syntax | Specify | Pending |
| EDT-04 | P1: Edição + syntax | Specify | Pending |
| EDT-05 | P1: Undo/Redo | Specify | Pending |
| EDT-06 | P1: Undo/Redo | Specify | Pending |
| EDT-07 | P1: Undo/Redo | Specify | Pending |
| EDT-08 | P1: Undo/Redo | Specify | Pending |
| EDT-09 | P1: Busca/Replace | Specify | Pending |
| EDT-10 | P1: Busca/Replace | Specify | Pending |
| EDT-11 | P1: Busca/Replace | Specify | Pending |
| EDT-12 | P1: Busca/Replace | Specify | Pending |
| EDT-13 | P1: Busca/Replace | Specify | Pending |
| EDT-14 | P1: Abas | Specify | Pending |
| EDT-15 | P1: Abas | Specify | Pending |
| EDT-16 | P1: Abas | Specify | Pending |
| EDT-17 | P1: Abas | Specify | Pending |
| EDT-18 | P2: Menubar/Toolbar | Specify | Pending |
| EDT-19 | P2: Menubar/Toolbar | Specify | Pending |
| EDT-20 | P2: Menubar/Toolbar | Specify | Pending |
| EDT-21 | P2: Menubar/Toolbar | Specify | Pending |
| EDT-22 | P3: Configurações | Specify | Pending |
| EDT-23 | P3: Configurações | Specify | Pending |
| EDT-24 | P3: Configurações | Specify | Pending |
| EDT-25 | P3: Configurações | Specify | Pending |

**ID format:** `EDT-NN` (Editor)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 25 total, 0 mapped to tasks, 25 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] F4 em arquivo abre editor com syntax highlighting; digitação/auto-indent; Ctrl+S salva; fechar com prompt.
- [ ] Ctrl+Z/Ctrl+Y undo/redo ilimitado funciona corretamente; salva não limpa stack.
- [ ] Ctrl+F busca com regex highlights; F3/Shift+F3 navega; Ctrl+H replace all conta substituições.
- [ ] Múltiplos F4 abrem abas; Ctrl+Tab alterna; Ctrl+W fecha com prompt; tab header mostra nome + *.
- [ ] Menu `File > Edit` habilitado; toolbar F1-F10 com labels MC; F2=Save, F10=Quit.
- [ ] Config (F8): tab width, spaces, wrap, whitespace, line numbers persistem.
- [ ] Suite de testes existente (236) continua passando; novos testes cobrem editor (unit Core/App, UAT visual).
- [ ] Build com `-warnaserror` limpo.