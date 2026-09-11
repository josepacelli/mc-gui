# Editor (F4) Design

## Arquitetura

Segue o padrão já validado no projeto (AD-001 + lição do viewer-f3: manter lógica testável em C# puro, UI fina em Avalonia):

- **McGui.Core**: modelos (`EditorDocumentState`) + interface `IEditorService` (load/save) — sem dependência de SO/UI.
- **McGui.Infrastructure.macOS**: `MacEditorService` — I/O real (UTF-8 com detecção de BOM, fallback Latin-1, arquivo grande chunked).
- **McGui.App/ViewModels**: `EditorWindowViewModel` (orquestra abas, dirty-state, prompt save) — C# puro testável.
- **McGui.App/Views**: `EditorWindow` (janela com toolbar F1-F10, `TabControl` de `TextEditor` do AvaloniaEdit).
- **McGui.App/Input**: liga F4/GestureAction.Edit (removido de DisabledActions) + atalhos internos do editor.

## Dependência

`Avalonia.AvaloniaEdit` **12.0.0** (pacote oficial, port do AvalonEdit p/ Avalonia 12). Fornece `TextEditor`, undo/redo, busca visual opcional, highlight via `SyntaxHighlighting`/`.xshd`.

**Decisão de risco (aprendida com viewer T5):** NÃO usar template-selector/data-trigger para modos. Editor = 1 controle (`TextEditor`) por aba dentro de `TabControl`. O que varia entre abas é o *conteúdo*, não o *template* — elimina a classe de bug que travou o hex mode do viewer.

## Fluxo de dados

```
F4 / File>Edit no arquivo
  → MainWindowViewModel.EditRequested(FileEntry)
  → MainWindow.axaml.cs abre EditorWindow com EditorWindowViewModel
  → VM chama IEditorService.LoadAsync(path) → string+encoding+isReadOnly
  → Aba criada: header = nome + (* se dirty)
  → Usuário digita → TextEditor.TextChanged → VM marca dirty
  → Ctrl+S → IEditorService.SaveAsync(path, text)
  → Fechar aba/window com dirty → prompt Salvar/Descartar/Cancelar
```

## Componentes

### Core (`McGui.Core`)

**`EditorDocumentState`** (record): `FilePath`, `Text`, `Encoding`, `IsReadOnly`, `IsDirty`, `SyntaxKey` (derivado da extensão).

**`IEditorService`**:
```csharp
public interface IEditorService {
    Task<EditorDocumentState> LoadAsync(string path, CancellationToken ct);
    Task SaveAsync(string path, string text, CancellationToken ct);
    bool IsReadOnly(string path);
}
```

### Infrastructure

**`MacEditorService`**: `LoadAsync` lê bytes (BOM UTF-8 → UTF-8; senão strict UTF-8 → Latin-1 fallback; mesmo padrão do `MacViewerService`); `IsReadOnly` = `File.GetUnixFileMode` sem bit de escrita. Arquivo > 50MB → retorna flag para desabilitar syntax no carregamento.

### App ViewModel

**`EditorWindowViewModel`** (`ObservableObject`, `ICompletable`):
- `ObservableCollection<EditorTabViewModel> Tabs`, `SelectedTab`
- `OpenFile(path)` → se já aberto, foca a aba; senão carrega e adiciona
- `SaveCommand`/`SaveAsCommand`/`CloseTabCommand`/`NextTabCommand`/`PrevTabCommand`
- `HasDirtyTabs`, prompt de fechamento (Salvar/Descartar/Cancelar)

**`EditorTabViewModel`**:
- `FileEntry`, `DocumentText`, `IsDirty`, `Title` (nome + *), `Encoding`, `IsReadOnly`
- `IsDirty` derivado: compara texto inicial × atual (simples) OU flag setada no `TextChanged` (eficiente; usa flag + reset ao salvar)
- Guarda `_savedText` para dirty-check por comparação (robusto contra undo que volta ao estado original)

### App View

**`EditorWindow.axaml`**: DockPanel — toolbar F1-F10 no topo (Save F2, Search F3, Replace F4, ..., Quit F10), `TabControl` central (`TextEditor` por aba), status bar (encoding, linha/coluna, RO).

**Toolbar F-keys** (labels MC): `Help`(F1) `Save`(F2) `Find`(F3) `Replace`(F4) `Macro`(F5 desab) `Block`(F6 desab) `Spell`(F7 desab) `Config`(F8) `Menu`(F9 desab) `Quit`(F10).

### Menu / Keymap

- `McMenuDefinitions`: `File > Edit` habilitado (CommandName "Edit").
- `KeyGestureMap`: F4 já mapeia `GestureAction.Edit`; remover de `DisabledActions`.
- `MainWindowViewModel`: `RequestEdit` → `EditRequested` event (espelha `RequestView`/`ViewRequested`).
- `MainWindow.axaml.cs`: trata `GestureAction.Edit` + `EditRequested` → abre `EditorWindow`.

### Atalhos internos editor
AvaloniaEdit já fornece Ctrl+Z/Y, setas, Home/End, seleção, Ctrl+A/C/V/X. Adicionar: F2/Ctrl+S save, F3 busca (find-panel próprio), F10 close, Ctrl+W fecha aba, Ctrl+Tab próxima aba.

## Busca/Substituição
Panel custom (`SearchBar` collapsível, mesmo padrão do ViewerWindow): input, regex/case/whole toggles, Prev/Next, e mode Replace com botão Replace All. Implementação via regex .NET sobre o texto (não depender de UI interna do AvaloniaEdit p/ manter testável) + seleção/jump via `TextEditor` (offset calculado).

## Testes

- **Core**: `EditorDocumentState` (record), nada além.
- **Infra** (`McGui.Infrastructure.macOS.Tests`): `MacEditorServiceTests` — load UTF-8/BOM/Latin-1, save round-trip, read-only detection, arquivo grande.
- **App VM** (`McGui.App.Tests`): `EditorWindowViewModelTests` — abrir 2º arquivo foca em vez de duplicar, dirty-check (edita→dirty, save→limpo, undo ao original→limpo), Save/SaveAs, fechar aba com dirty→prompt, Ctrl+Tab ciclo, tab header título. Lógica de busca/replace: helper puro `SearchService` testável (regex/case/whole, counts).
- **Estrutural**: XAML toolbar F1-F10, TabControl, search bar presente (text/regex, padrão do repo).
- **Menu/keymap**: `File > Edit` habilitado; `GestureAction.Edit` fora de DisabledActions.

## Rollout (fases → tasks)

1. **T1** — Core + `IEditorService` + `MacEditorService` + testes.
2. **T2** — `EditorTabViewModel` + `EditorWindowViewModel` (abas, dirty, save) + testes.
3. **T3** — `SearchService` (regex/case/whole/replace-all) + testes.
4. **T4** — `EditorWindow.axaml` + code-behind (toolbar, TabControl+TextEditor, status bar) + testes estruturais.
5. **T5** — Integração: menu File>Edit, F4 ativo, `MainWindowViewModel.EditRequested`, abertura da janela + testes.
6. **T6** — Atalhos internos (F2/F10/Ctrl+W/Ctrl+Tab/busca) + prompt dirty no fechamento + testes.

Cada task: gate próprio + commit atômico + testes antes.
