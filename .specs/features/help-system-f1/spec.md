# Help System (F1) Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje tem o botão F1 "Help" na toolbar e menu `File > View` desabilitado, mas não tem sistema de ajuda. O Midnight Commander original possui um sistema de ajuda contextual (F1) que mostra páginas de manual em formato texto/HTML sobre: teclas de atalho, comandos, configuração, FAQ, e ajuda específica do contexto atual (painel, viewer, editor, diálogo). O sistema usa arquivos `.hlp` instalados com o MC. Esta feature entrega o sistema de ajuda no mc-gui: visualizador de ajuda (F1) com navegação por tópicos, busca, histórico, e ajuda contextual sensível ao foco atual (painel, viewer, editor, diálogo ativo).

## Goals

- [ ] Botão F1 "Help" na toolbar funcional; menu `Help` (novo top-level menu) com itens: `Contents` (F1), `Keyboard shortcuts`, `FAQ`, `About`.
- [ ] Janela de ajuda (`Window`) com: sidebar de tópicos (árvore), área de conteúdo (renderizado Markdown/HTML), toolbar com Back/Forward/Home/Search/Print.
- [ ] Conteúdo de ajuda embutido como recursos Markdown (`.md`) no assembly: `help/contents.md`, `help/shortcuts.md`, `help/faq.md`, `help/config.md`, `help/viewer.md`, `help/editor.md`, `help/vfs.md`, `help/background.md`.
- [ ] Ajuda contextual: F1 em qualquer widget/foco abre ajuda relevante (ex.: foco no painel → `help/panels.md#navigation`; foco no viewer → `help/viewer.md`; foco no editor → `help/editor.md`; foco em diálogo → seção específica do diálogo).
- [ ] Busca full-text no conteúdo de ajuda (Ctrl+F na janela de ajuda); resultados com highlights.
- [ ] Histórico de navegação (Back/Forward buttons) e favoritos (bookmark tópicos).
- [ ] Menu `Help > Keyboard shortcuts` abre página com tabela completa de atalhos (F1-F10, Ctrl+, Alt+, etc.).
- [ ] Menu `Help > About` mostra versão, copyright, licença, link do repositório.

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Ajuda online/atualização automática | App offline-first; docs no repositório |
| Tradução/localização de ajuda | Inglês apenas no MVP; i18n depois |
| Editor de ajuda integrado | Conteúdo versionado no git; não editável no app |
| Integração com `man` pages do sistema | Complexidade de parsing; links para man pages online se necessário |
| Anotações/notes do usuário na ajuda | Feature futura |
| Tooltips contextuais (hover) | F1 abre janela completa; tooltips são separado |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Formato do conteúdo | Markdown (`.md`) renderizado via `Markdown.Wpf` / `Markdig` + Avalonia `MarkdownTextBlock` | Padrão moderno, versionável, legível no git | n |
| Renderização | `Markdown.Avalonia` ou `Markdig` + custom renderer para Avalonia | Suporte a tabelas, code blocks, links internos | n |
| Navegação interna | Links `[text](#anchor)` no Markdown → scroll para heading; `[text](help:topic)` → navega para outro tópico | Semelhante a wiki | n |
| Busca | Índice invertido construído no startup (títulos + conteúdo); `TextBox` + `ListBox` resultados | Rápido, offline | n |
| Contexto | `FocusManager` trackea foco atual; `HelpService.GetContextualHelp(focusedControl)` retorna tópico/anchor | Centralizado | n |
| Janela | Modeless (`Window.Show()`), dockable lateral ou flutuante; `Topmost=false` | Permite consultar ajuda enquanto usa app | n |
| Atalhos na ajuda | F1 = abre/fecha ajuda; Esc = fecha; Ctrl+F = busca; Alt+Left/Right = Back/Forward | Consistente com browser | n |
| Testes | Unit: HelpService (contexto, busca índice); UAT: F1 contextual, navegação, busca | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Janela de ajuda com navegação e busca ⭐ MVP

**User Story**: Como usuário, quero pressionar F1 e ver uma janela de ajuda com tópicos organizados, busca, e navegação Back/Forward, para aprender a usar o mc-gui.

**Why P1**: Help system é expectativa básica de qualquer app GUI; F1 é universal.

**Acceptance Criteria**:

1. WHEN the user presses F1 THEN a Help window SHALL open (modeless) with sidebar (topics tree) on left, content area on right, and toolbar (Back, Forward, Home, Search, Print).
2. THE sidebar SHALL show hierarchical topics: `Getting Started`, `Panels & Navigation`, `File Operations`, `Viewer (F3)`, `Editor (F4)`, `VFS & Network`, `Background Jobs`, `Configuration`, `Keyboard Shortcuts`, `FAQ`.
3. WHEN the user clicks a topic THEN the content area SHALL render the corresponding Markdown with syntax highlighting for code blocks.
4. WHEN the user types in the Search box THEN matching topics/sections SHALL be listed with snippets; clicking a result navigates and highlights.
5. BACK/Forward buttons SHALL navigate history; Home button goes to `Getting Started`.

**Independent Test**: F1 abre ajuda; clica "File Operations" → vê copy/move/delete; busca "chmod" → salta para seção; Back volta.

---

### P1: Ajuda contextual (F1 sensível ao foco) ⭐ MVP

**User Story**: Como usuário, quero que F1 abra a ajuda relevante para onde estou (painel, viewer, editor, diálogo), para não ter que procurar manualmente.

**Why P1**: Diferencial de UX; MC original tem ajuda contextual.

**Acceptance Criteria**:

1. WHEN the user presses F1 while the active panel has focus THEN the Help window SHALL open at `help/panels.md#navigation` (or equivalent anchor).
2. WHEN the user presses F1 while the Viewer (F3) has focus THEN Help SHALL open at `help/viewer.md`.
3. WHEN the user presses F1 while the Editor (F4) has focus THEN Help SHALL open at `help/editor.md`.
4. WHEN the user presses F1 while a dialog is open (Copy, Move, chmod, etc.) THEN Help SHALL open at the dialog-specific section (e.g., `help/file-operations.md#copy-dialog`).
5. IF no specific context mapping exists THEN Help SHALL open at `Getting Started`.

**Independent Test**: Foco no painel → F1 → painéis; abre viewer → F1 → viewer; abre chmod dialog → F1 → chmod section.

---

### P2: Páginas especiais: Shortcuts, FAQ, About ⭐ MVP

**User Story**: Como usuário, quero acessar rapidamente a tabela de atalhos, FAQ, e info do app via menu Help.

**Why P2**: Referências rápidas essenciais; menu Help padrão.

**Acceptance Criteria**:

1. THE `Help > Keyboard shortcuts` menu item SHALL open `help/shortcuts.md` with a formatted table of all shortcuts (F1-F10, Ctrl+, Alt+, chords).
3. THE `Help > FAQ` menu item SHALL open `help/faq.md` with common questions.
4. THE `Help > About` menu item SHALL open a dialog (not Help window) with: app name, version, copyright, license (GPL-3), repository URL, build info.
5. THE Help window SHALL have a `Help > Contents` (F1) item that focuses the Help window if open, or opens it at `Getting Started`.

---

## Edge Cases

- IF the Help window is already open and user presses F1 THEN it SHALL focus the existing window and navigate to contextual topic.
- IF the help content Markdown has broken internal links THEN the renderer SHALL show placeholder "Section not found" without crashing.
- IF the user searches for term with no matches THEN show "No results found" with suggestion to check spelling.
- WINDOW state (size, position, sidebar width) SHALL persist across sessions.
- PRINT button SHALL use system print dialog to print current topic.
- HIGH DPI: Markdown rendering SHALL scale correctly.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| HLP-01 | P1: Janela ajuda + navegação | Specify | Pending |
| HLP-02 | P1: Janela ajuda + navegação | Specify | Pending |
| HLP-03 | P1: Janela ajuda + navegação | Specify | Pending |
| HLP-04 | P1: Janela ajuda + navegação | Specify | Pending |
| HLP-05 | P1: Janela ajuda + navegação | Specify | Pending |
| HLP-06 | P1: Ajuda contextual | Specify | Pending |
| HLP-07 | P1: Ajuda contextual | Specify | Pending |
| HLP-08 | P1: Ajuda contextual | Specify | Pending |
| HLP-09 | P1: Ajuda contextual | Specify | Pending |
| HLP-10 | P1: Ajuda contextual | Specify | Pending |
| HLP-11 | P2: Shortcuts/FAQ/About | Specify | Pending |
| HLP-12 | P2: Shortcuts/FAQ/About | Specify | Pending |
| HLP-13 | P2: Shortcuts/FAQ/About | Specify | Pending |
| HLP-14 | P2: Shortcuts/FAQ/About | Specify | Pending |

**ID format:** `HLP-NN` (Help)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 14 total, 0 mapped to tasks, 14 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] F1 abre Help window modeless com sidebar, conteúdo, toolbar; navegação Back/Forward/Home/Search funciona.
- [ ] F1 contextual: painel→panels, viewer→viewer, editor→editor, dialogs→seção específica.
- [ ] Busca full-text com highlights; resultados clicáveis navegam.
- [ ] Menu Help: Contents (F1), Keyboard shortcuts, FAQ, About funcionais.
- [ ] Conteúdo Markdown embutido no assembly; renderização correta (tabelas, code blocks, links internos).
- [ ] Suite de testes existente (236) continua passando; novos testes: HelpService contexto/busca; UAT visual.
- [ ] Build com `-warnaserror` limpo.