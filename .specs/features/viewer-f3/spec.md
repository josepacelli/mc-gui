# Viewer (F3) Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje não tem visualizador de arquivos interno. O Midnight Commander original possui um visualizador completo (F3) acessível via tecla F3 ou menu `File > View`/`File > View file...` que suporta: visualização de texto com wrap, modo hexadecimal (F4), modo nroff para man pages, modo "magic" (detecção automática de tipo + filtros externos), busca incremental, e salvamento de posição de leitura. Esta feature (fatia A) entrega um visualizador GUI funcional no mc-gui, acessível via F3 no painel ativo e item de menu `File > View`, com as modalidades essenciais: texto (com wrap), hex, busca, e navegação por teclado/mouse. Modos nroff/magic e filtros externos ficam para fase futura.

## Goals

- [ ] Pressionar F3 em um arquivo abre o visualizador em janela/modal com o conteúdo do arquivo.
- [ ] Visualizador exibe texto com wrap automático; alternância de wrap via tecla/mouse.
- [ ] Visualizador tem modo hexadecimal (toggle via F4 ou botão), mostrando offset, bytes hex, e representação ASCII.
- [ ] Busca incremental (Ctrl+F ou botão) destaca ocorrências; navegação próximo/anterior.
- [ ] Navegação por teclado: setas (scroll linha), PageUp/PageDown (página), Home/End (início/fim), Enter (segue link se aplicável).
- [ ] Mouse: scroll wheel, clique para posicionar cursor, seleção de texto para copiar.
- [ ] Janela do visualizador tem barra de botões F1-F10 no estilo mc-gui (Help, Hex/Ascii, Save, Search, etc.).
- [ ] Fechar visualizador (Esc, F10, botão fechar) retorna ao painel mantendo foco.
- [ ] Item de menu `File > View` (F3) habilitado no menubar; `File > View file...` desabilitado (fora do escopo desta fatia).

## Out of Scope

Explicitamente excluído desta feature (fatia B separada).

| Feature | Motivo |
| --- | --- |
| Modo nroff (renderização de man pages) | Complexidade de formatação nroff/troff; feature futura |
| Modo "magic" (filtros externos por extensão) | Exige configuração de filtros/executáveis externos; feature futura |
| Visualização de output de comando (ex.: `cat file | less`) | Fora do escopo de visualizador de arquivo |
| Edição no visualizador (hexedit) | Editor é feature separada (F4) |
| Syntax highlighting por linguagem | Feature futura; visualizador base é texto plano/hex |
| Persistência de posição de leitura entre sessões | Nice-to-have; pode ser adicionado depois |
| Quick view no painel (Ctrl+X, Q) | Feature P3 do dual-pane-core (DPC-39), não implementada |
| Encoding detection/conversão avançada | Visualizador usa UTF-8; fallback para encoding detectado |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Formato da janela | Janela modal (`Window`) separada, não dialog | Visualizador ocupa tela cheia ou grande área; `Window` permite toolbar própria e melhor UX que `Dialog` | n |
| Dados do arquivo | Carregados via `IFileSystemService` (stream) ou lidos em memória se < 10MB; arquivos maiores usam virtualização/paginação | Evita OOM em arquivos grandes; MC original lê em chunks | n |
| Encoding | UTF-8 com fallback para Latin-1 se inválido | Simplicidade; MC original tem `str_cnv_from_term` complexo | n |
| Hex mode | Toggle via F4 (tecla) ou botão na toolbar; mostra offset (8 dígitos hex), 16 bytes por linha, ASCII à direita | Padrão MC clássico | n |
| Busca | `TextBox` + highlights no `TextBlock`/`RichTextBlock`; Ctrl+F foca busca; F3/Shift+F3 próximo/anterior | Padrão GUI moderno | n |
| Toolbar F-keys | Reutiliza padrão `PanelView` (botões F1-F10) com labels específicas do visualizador | Consistência visual | n |
| Teclas de navegação | Setas, PgUp/PgDn, Home/End, Enter; F4 toggle hex; F5 reload; F7 search; F10/Escape close | Mapeamento próximo do MC original | n |
| Teste de visualização | Lógica (carregamento, modos, busca) em xunit; renderização visual por build-gate + UAT | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Visualizador de texto com wrap ⭐ MVP

**User Story**: Como usuário, quero pressionar F3 em um arquivo e ver seu conteúdo em texto com wrap automático, para ler arquivos de texto/logs sem sair do gerenciador.

**Why P1**: Funcionalidade central do F3 no MC; base para demais modos.

**Acceptance Criteria**:

1. WHEN the user presses F3 on a selected file entry in the active panel THEN the system SHALL open a viewer window displaying the file's text content with word wrap enabled by default.
2. WHEN the viewer window is open THEN the user SHALL be able to scroll vertically using Up/Down arrows, PageUp/PageDown, mouse wheel, and scrollbar.
3. WHEN the user presses the wrap toggle key (F2 or toolbar button) THEN the viewer SHALL toggle word wrap on/off and reflow the text accordingly.
4. WHEN the user closes the viewer (Esc, F10, or close button) THEN the system SHALL return focus to the originating panel without data loss.

**Independent Test**: Selecionar um arquivo `.txt`/`log` grande no painel, pressionar F3, confirmar wrap ativo, scroll funcionar, F2 toggle wrap, Esc fecha e foco volta ao painel.

---

### P1: Modo hexadecimal ⭐ MVP

**User Story**: Como usuário, quero alternar para modo hexadecimal no visualizador (F4), para inspecionar bytes brutos de arquivos binários.

**Why P1**: Modo hex é feature icônica do MC viewer; essencial para arquivos binários.

**Acceptance Criteria**:

1. WHEN the viewer is open and the user presses F4 or clicks the "Hex/Ascii" toolbar button THEN the viewer SHALL switch to hex mode displaying: 8-digit hex offset, 16 bytes per line as hex pairs, and printable ASCII representation on the right.
2. WHEN in hex mode and the user presses F4 again THEN the viewer SHALL return to text mode at the corresponding position.
3. WHEN in hex mode THEN vertical navigation (arrows, PgUp/PgDn) SHALL move by lines (16 bytes each), and horizontal navigation SHALL move the column offset.
4. THE hex display SHALL use a monospace font for alignment.

**Independent Test**: Abrir um arquivo binário (ex.: `.exe`, `.dll`, imagem) com F3, pressionar F4 → modo hex com offsets/bytes/ASCII; F4 volta ao texto; scroll funciona em ambos.

---

### P1: Busca incremental ⭐ MVP

**User Story**: Como usuário, quero buscar texto dentro do visualizador (Ctrl+F), com highlights e navegação próximo/anterior, para localizar conteúdo rapidamente.

**Why P1**: Busca é essencial para logs/arquivos grandes; MC original tem busca integrada.

**Acceptance Criteria**:

1. WHEN the user presses Ctrl+F in the viewer THEN a search input SHALL appear focused at the top/bottom of the viewer window.
2. WHILE the user types in the search input THEN the viewer SHALL highlight all matching occurrences in the current view (case-insensitive by default).
3. WHEN the user presses Enter/F3 in the search input THEN the viewer SHALL jump to the next match; Shift+Enter/Shift+F3 SHALL jump to the previous match.
4. WHEN the user presses Esc in the search input THEN the search SHALL close and highlights SHALL be cleared.

**Independent Test**: Abrir arquivo grande, Ctrl+F digitar "error", confirmar highlights e navegação Enter/Shift+Enter; Esc limpa busca.

---

### P2: Integração com menubar e teclas F ⭐ MVP

**User Story**: Como usuário, quero acessar o visualizador via menu `File > View` (F3) e ver a toolbar F1-F10 contextual no visualizador, para operar consistente com o resto do mc-gui.

**Why P2**: Integração UI completa; menubar já tem item `View` desabilitado — agora habilita.

**Acceptance Criteria**:

1. THE `File > View` menu item SHALL be enabled and SHALL open the viewer for the currently selected file in the active panel (same as F3 key).
2. THE viewer window SHALL display a function key toolbar (F1-F10) with labels: `Help`, `Hex/Ascii`, `Save`, `Search`, `...`, `Quit` (F10), matching MC viewer buttonbar.
3. WHEN the user presses F10 in the viewer THEN the viewer SHALL close (same as Esc).

**Independent Test**: Menu File > View abre visualizador; toolbar mostra labels corretas; F10 fecha.

---

### P3: Mouse interaction e seleção

**User Story**: Como usuário, quero usar mouse para scroll, posicionar cursor, e selecionar/copiar texto no visualizador, para fluxo GUI nativo.

**Why P3**: Valor agregado GUI; MC terminal não tem seleção de texto rica.

**Acceptance Criteria**:

1. WHEN the user scrolls the mouse wheel in the viewer THEN the content SHALL scroll vertically.
2. WHEN the user clicks in the text area THEN the text cursor/caret SHALL move to that position.
3. WHEN the user drags to select text THEN the selection SHALL be highlighted and Ctrl+C SHALL copy to clipboard.
4. WHEN the user double-clicks a word THEN that word SHALL be selected.

---

## Edge Cases

- IF the selected entry is a directory THEN F3/View SHALL do nothing (or show directory listing? MC original doesn't view dirs — do nothing).
- IF the file is empty THEN the viewer SHALL show an empty view with "Empty file" placeholder.
- IF the file is larger than 100MB THEN the viewer SHALL load in chunks/virtualized mode and show a "Loading..." indicator, not freeze the UI.
- IF the file contains invalid UTF-8 sequences THEN the viewer SHALL display replacement characters (�) without crashing.
- WHEN the viewer is open and the underlying file is deleted/modified externally THEN the viewer SHALL show a notification and offer to reload (F5).
- IF the user opens multiple viewers THEN each SHALL be an independent window (MC original allows only one — GUI pode permitir múltiplas).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| VWR-01 | P1: Texto com wrap | Specify | Pending |
| VWR-02 | P1: Texto com wrap | Specify | Pending |
| VWR-03 | P1: Texto com wrap | Specify | Pending |
| VWR-04 | P1: Texto com wrap | Specify | Pending |
| VWR-05 | P1: Modo hex | Specify | Pending |
| VWR-06 | P1: Modo hex | Specify | Pending |
| VWR-07 | P1: Modo hex | Specify | Pending |
| VWR-08 | P1: Modo hex | Specify | Pending |
| VWR-09 | P1: Busca | Specify | Pending |
| VWR-10 | P1: Busca | Specify | Pending |
| VWR-11 | P1: Busca | Specify | Pending |
| VWR-12 | P1: Busca | Specify | Pending |
| VWR-13 | P2: Menubar/Toolbar | Specify | Pending |
| VWR-14 | P2: Menubar/Toolbar | Specify | Pending |
| VWR-15 | P2: Menubar/Toolbar | Specify | Pending |
| VWR-16 | P3: Mouse | Specify | Pending |
| VWR-17 | P3: Mouse | Specify | Pending |
| VWR-18 | P3: Mouse | Specify | Pending |
| VWR-19 | P3: Mouse | Specify | Pending |

**ID format:** `VWR-NN` (Viewer)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 19 total, 0 mapped to tasks, 19 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] F3 em arquivo abre visualizador com texto wrap; scroll teclado/mouse; F2 toggle wrap; Esc/F10 fecha.
- [ ] F4 alterna modo hex (offset/hex/ASCII) ↔ texto; navegação funciona em ambos.
- [ ] Ctrl+F abre busca; highlights funcionam; Enter/Shift+Enter navega matches; Esc fecha busca.
- [ ] Menu `File > View` habilitado e funcional; toolbar F1-F10 no visualizador com labels corretas.
- [ ] Mouse: scroll, click posiciona, drag seleciona, Ctrl+C copia.
- [ ] Suite de testes existente (236) continua passando; novos testes cobrem viewer (unit no Core/App, UAT visual).
- [ ] Build com `-warnaserror` limpo.