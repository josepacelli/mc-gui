# Editor (F4) Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/editor-f4/design.md`
**Status**: Approved

---

## Test Coverage Matrix

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Core model (`EditorDocumentState`) | unit | construction/equality | `tests/McGui.Core.Tests/Models/EditorDocumentStateTests.cs` | `dotnet test tests/McGui.Core.Tests` |
| Infrastructure (`MacEditorService`) | unit (real temp-dir I/O) | load UTF-8/BOM/Latin-1, save round-trip, read-only, large | `tests/McGui.Infrastructure.macOS.Tests/MacEditorServiceTests.cs` | `dotnet test tests/McGui.Infrastructure.macOS.Tests` |
| App ViewModel (`EditorWindowViewModel`, `EditorTabViewModel`) | unit | open/focus-dedup, dirty, save, close prompt, tab cycle | `tests/McGui.App.Tests/ViewModels/EditorWindowViewModelTests.cs` | `dotnet test tests/McGui.App.Tests` |
| Search helper (`EditorSearch`) | unit | regex/case/whole, replace-all counts | `tests/McGui.App.Tests/EditorSearchTests.cs` | `dotnet test tests/McGui.App.Tests` |
| App XAML structure | unit (text/regex on `.axaml`) | toolbar F1-F10, TabControl, search bar | `tests/McGui.App.Tests/EditorWindowStructureTests.cs` | `dotnet test tests/McGui.App.Tests` |
| Menu/keymap integration | unit | File>Edit enabled, Edit not disabled | `tests/McGui.App.Tests/McMenuDefinitionsTests.cs`, `.../Input/KeyGestureMapTests.cs` | `dotnet test tests/McGui.App.Tests` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Task touching one test project | `dotnet test tests/<ProjectName>` |
| Full | Task touching >1 project, or end of feature | `dotnet build McGui.sln && dotnet test McGui.sln` |
| Build | Markup/dependency-only task | `dotnet build McGui.sln` |

---

## Execution Plan

```
T1 → T2 ──→ T4 → T5 → T6
       ↘
T3 ────────→ T4
```

Fases: T1; T2; T3 (independe de T2 — pode rodar em paralelo); T4 (depende de T2 e T3); T5; T6. Serial T1→T2→T3→T4→T5→T6 é válido.

---

## Task Breakdown

### T1: `EditorDocumentState` + `IEditorService` + `MacEditorService`

**What**: Modelo Core + interface + implementação macOS de load/save de texto com detecção de encoding (reusa padrão do `MacViewerService`).
**Where**: `src/McGui.Core/Models/EditorDocumentState.cs` (new), `src/McGui.Core/Interfaces/IEditorService.cs` (new), `src/McGui.Infrastructure.macOS/MacEditorService.cs` (new)
**Depends on**: None
**Requirement**: EDT-01 (load), EDT-03 (save)

**Done when**:
- [ ] `EditorDocumentState` record: `FilePath`, `Text`, `Encoding`, `IsReadOnly`, `IsLarge` (bool se >50MB)
- [ ] `IEditorService`: `Task<EditorDocumentState> LoadAsync(path, ct)`, `Task SaveAsync(path, text, ct)`, `bool IsReadOnly(path)`
- [ ] `MacEditorService`: load UTF-8 (BOM-aware) → Latin-1 fallback (strict decoder, mesmo padrão `MacViewerService`); `IsReadOnly` checa `UnixFileMode` sem bit write; arquivo >50MB → `IsLarge=true`
- [ ] `dotnet test tests/McGui.Core.Tests` + `dotnet test tests/McGui.Infrastructure.macOS.Tests` verdes com testes novos

**Tests**: unit (~8 facts: load utf8/bom/latin1, save roundtrip, readonly true/false, large flag)
**Gate**: full
**Commit**: `feat(core,infra): add editor document model and MacEditorService load/save`

---

### T2: `EditorWindowViewModel` + `EditorTabViewModel` (abas, dirty, save)

**What**: VM que gerencia múltiplas abas de editor com dirty-check por comparação com texto salvo, save/save-as, foco-em-vez-de-duplicar, ciclo de abas, prompt de fechamento.
**Where**: `src/McGui.App/ViewModels/EditorTabViewModel.cs`, `EditorWindowViewModel.cs` (new) + testes
**Depends on**: T1
**Requirement**: EDT-01..04, EDT-14..17 (abas), EDT-22 (dirty flag na aba)

**Done when**:
- [ ] `EditorTabViewModel`: `FilePath`, `Title` (nome + `*` quando dirty), `DocumentText`, `IsDirty` (via comparação com `_savedText`), `IsReadOnly`, `Encoding`; `SetSaved()` reseta base
- [ ] `EditorWindowViewModel`: `Tabs`, `SelectedTab`, `OpenFileAsync(path)` (dedup: já aberto → foca; senão load+add), `SaveCommand`, `SaveAsCommand`, `CloseTabCommand`, `NextTabCommand` (ciclico), `PrevTabCommand`, `CanCloseAll`/`HasDirtyTabs`
- [ ] dirty: editar texto → `IsDirty=true`; save → `false`; restaurar texto original (undo) → `false`
- [ ] Testes verdes

**Tests**: unit (~12 facts)
**Gate**: quick
**Commit**: `feat(app): add editor tab/window ViewModels with dirty tracking and save`

---

### T3: `EditorSearch` (busca/substituição regex)

**What**: Helper puro de busca/substituição em texto (regex/case-sensitive/whole-word, next/prev, replace-all com contagem), testável sem UI.
**Where**: `src/McGui.App/EditorSearch.cs` (new, namespace `McGui.App`) + `tests/McGui.App.Tests/EditorSearchTests.cs`
**Depends on**: None (pode rodar em paralelo com T2)
**Requirement**: EDT-09..13 (busca/replace)

**Done when**:
- [ ] `FindAll(text, pattern, options)` → lista de `(Index, Length)` ordenada; `case-sensitive`, `whole-word`, `regex` (escapa se não-regex)
- [ ] `ReplaceAll(text, pattern, replacement, options)` → `(novoTexto, count)`
- [ ] Case-insensitive + regex funcionam; whole-word evita substring parcial
- [ ] Testes verdes

**Tests**: unit (~10 facts)
**Gate**: quick
**Commit**: `feat(app): add pure EditorSearch helper with regex/case/whole-word`

---

### T4: `EditorWindow.axaml` + code-behind (toolbar, abas TextEditor, status)

**What**: Janela do editor: toolbar F1-F10 (labels MC), `TabControl` com `TextEditor` (AvaloniaEdit) por aba, search/replace bar collapsível, status bar (encoding/RO/posição). Requer adicionar pacote `Avalonia.AvaloniaEdit` 12.0.0 ao csproj.
**Where**: `src/McGui.App/McGui.App.csproj` (+package), `src/McGui.App/Views/EditorWindow.axaml` + `.axaml.cs` (new), `tests/McGui.App.Tests/EditorWindowStructureTests.cs`
**Depends on**: T2, T3
**Requirement**: EDT-01 (highlight por extensão), EDT-09..11 (UI busca), EDT-14..17 (UI abas), EDT-18..21 (toolbar)

**Done when**:
- [ ] Pacote `Avalonia.AvaloniaEdit` adicionado; build ok
- [ ] Toolbar com botões F1..F10 e labels `Help Save Find Replace Macro Block Spell Config Menu Quit` (desabilitados os que não têm função)
- [ ] `TabControl` central; cada aba é `TabItem` contendo `TextEditor` (AvaloniaEdit) com `SyntaxHighlighting` carregado por extensão quando não `IsLarge`/`IsReadOnly`
- [ ] Search bar collapsível ligada a `EditorSearch`
- [ ] Status bar: encoding, RO indicator, linha/coluna
- [ ] Testes estruturais (text/regex) verificam presença dos elementos; build ok

**Tests**: unit (estrutural ~6) + build
**Gate**: full (package novo + XAML)
**Commit**: `feat(app): add editor window with toolbar, tabs and AvaloniaEdit`

---

### T5: Integração menu/teclado + abertura da janela

**What**: Habilitar `File > Edit`, remover `GestureAction.Edit` de `DisabledActions`, `MainWindowViewModel.RequestEdit` + `EditRequested`, `MainWindow.axaml.cs` abre `EditorWindow`.
**Where**: `src/McGui.App/McMenuDefinitions.cs`, `src/McGui.App/Input/KeyGestureMap.cs`, `src/McGui.App/ViewModels/MainWindowViewModel.cs`, `src/McGui.App/MainWindow.axaml.cs`, `src/McGui.App/CompositionRoot.cs` (registrar `IEditorService`)
**Depends on**: T4
**Requirement**: EDT-01 (F4 abre), EDT-18 (File>Edit)

**Done when**:
- [ ] `File > Edit` habilitado (CommandName "Edit"); testes de menu atualizados
- [ ] `GestureAction.Edit` removido de `DisabledActions`; testes keymap atualizados
- [ ] `MainWindowViewModel` ganha `IEditorService`, `RequestEdit` (arquivo sob cursor; ignora dir) e event `EditRequested`
- [ ] `MainWindow.axaml.cs`: trata `GestureAction.Edit` e `EditRequested` → `ShowUntilCompletedAsync(new EditorWindow(), vm, noop)`; `EditorWindowViewModel` implementa `ICompletable`
- [ ] `CompositionRoot` registra `IEditorService`→`MacEditorService`, `MainWindowViewModel` com o novo ctor; testes de DI/VM atualizados (FakeEditorService)
- [ ] `dotnet test McGui.sln` verde

**Tests**: unit (menu/keymap/VM) + full
**Gate**: full
**Commit**: `feat(app): wire F4 and File>Edit to open the editor window`

---

### T6: Atalhos internos + prompt de fechamento com dirty

**What**: Atalhos F2/Save, F10/close, Ctrl+W fecha aba, Ctrl+Tab ciclo, Enter/F3 next-match na busca; confirmar fechamento (janela/aba) quando dirty → Salvar/Descartar/Cancelar. Se `IsReadOnly`, save vira "Save As".
**Where**: `src/McGui.App/Views/EditorWindow.axaml.cs` (key handling), `src/McGui.App/ViewModels/EditorWindowViewModel.cs` (prompt + save-as), testes
**Depends on**: T5
**Requirement**: EDT-04 (prompt dirty), EDT-15..16 (Ctrl+Tab/W), EDT-20 (F2 save), EDT-21 (F10 quit), EDT-11 (F3 next match)

**Done when**:
- [ ] KeyDown trata: F2=Ctrl+S save, F3=next match, F10/close, Ctrl+W fecha aba, Ctrl+Tab/Shift+Tab ciclo
- [ ] Fechar aba ou janela com aba dirty → prompt (Salvar/Descartar/Cancelar); Cancelar aborta
- [ ] Aba read-only: save → prompt "Save As"; salvar em novo path via dialog
- [ ] VM expõe `ICompletable.IsCompleted` (já usado no fluxo de janela); testes verdes

**Tests**: unit (~10 facts) + full
**Gate**: full
**Commit**: `feat(app): add editor shortcuts and dirty-close/save-as prompts`

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1 | Core+interface+impl macOS | ✅ Granular |
| T2 | 2 ViewModels + testes | ✅ Granular (coeso: abas/dirty/save) |
| T3 | 1 helper puro + testes | ✅ Granular |
| T4 | package + 1 view + code-behind | ✅ Granular |
| T5 | menu/keymap/VM/wiring | ✅ Granular (cross-cutting mas mecânico) |
| T6 | shortcuts + prompts | ✅ Granular |

## Diagram-Definition Cross-Check

| Task | Depends On | Diagram | Status |
| --- | --- | --- | --- |
| T1 | None | T1 | ✅ |
| T2 | T1 | T1→T2 | ✅ |
| T3 | None | T3 | ✅ (paralelo permitido) |
| T4 | T2, T3 | T2→T4, T3→T4 | ✅ |
| T5 | T4 | T4→T5 | ✅ |
| T6 | T5 | T5→T6 | ✅ |

## Test Co-location Validation

| Task | Layer | Matrix | Task | Status |
| --- | --- | --- | --- | --- |
| T1 | Core+Infra | unit | unit | ✅ |
| T2 | App VM | unit | unit | ✅ |
| T3 | App helper | unit | unit | ✅ |
| T4 | App XAML | unit (estrutural) | unit | ✅ |
| T5 | App (menu/keymap/VM) | unit | unit | ✅ |
| T6 | App (VM + view) | unit | unit | ✅ |

## Tips

- **Não usar template-selector/trigger por modo** — cada aba é 1 `TextEditor`; conteúdo varia, template não (lição do viewer T5).
- **Dirty por comparação** com texto salvo (`_savedText`) é mais robusto que flag manual: undo até o estado original limpa o dirty corretamente.
- **Syntax highlight**: `TextEditor.SyntaxHighlighting` por extensão; desligar se `IsLarge` (perf) — verificar API exata do AvaloniaEdit 12 na doc do pacote antes de codar T4.
- **EditorSearch puro** mantém busca/replace testável sem UI; a view só usa offsets para selecionar.
- Reusar `FakeViewerService` pattern para criar `FakeEditorService`.
- Um commit por task, Conventional Commits.

## Task Verification Standards

Cada task: `Done when` + `Tests` + `Gate` acima. `Done when` binário e referenciando o gate. Contagem de testes por arquivo para impedir deleção silenciosa.
