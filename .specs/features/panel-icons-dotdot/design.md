# Panel Icons + ".." Design

> Decisão de arquitetura para a feature `panel-icons-dotdot` (fatia A). Leitura complementar: `spec.md`.

## Visão geral

Duas mudanças coordenadas nos painéis:
1. **Ícones**: camada visual (PanelView DataTemplate) com `PathIcon` + geometria embutida, escolhendo pasta vs arquivo por `Entry.IsDirectory`.
2. **Entrada `..`**: entrada virtual injetada no topo de `PanelState.Entries` (exceto raiz), tratada como diretório na navegação mas nunca marcável/nem source de operação.

```
ListDirectory (Infra, entradas reais)
        │
        ▼
PanelViewModel.ApplyLoadedState ── injeta ".." (se não-raiz) no topo
        │                              CursorIndex aponta p/ 1º item real
        ▼
PanelState.Entries = [ ".."? ] + reais
        │
        ├── SelectionService (Core): Toggle/MarkByPattern/Unmark/Invert pulam nome ".."
        ├── PanelViewModel: ActivateCursorEntry em ".." → sobe e pousa cursor na origem
        └── PanelView: ícone + nome; ".." mostra ícone de pasta
```

## Decisões

### D1. Onde nasce a entrada `..`

- `PanelViewModel` cria a entrada virtual: `new FileEntry("..", parentPath, IsDirectory: true, ...)`.
- Inserida no topo de `_state.Entries` **somente quando** `Path.GetDirectoryName(current)` retorna não-nulo (raiz não tem pai).
- Marcação identifica a entrada virtual pelo `Name == ".."` (mesma ideia de `DIR_IS_DOTDOT` no MC). `FullPath` do `..` aponta para o diretório pai (não é marcado nem vira source, então nunca é usado em operação).

**Por quê**: manter a lista exibida e a lista de navegação iguais (cursor/index 1:1) é o modelo do MC — o `..` vive na lista do painel, não no serviço. Camada App injeta, Core guarda.

### D2. Cursor e navegação

- **Ao entrar** em um diretório (navegação descendente via Enter/duplo-clique em um item real): `CursorIndex = 0` **se não há `..`** (raiz ou lista sem pai), senão `1` (1º item real). Nunca pousa em `..` ao entrar.
- **Ao subir via `..`** (Enter/duplo-clique na linha `..`): computa `originName = Path.GetFileName(current)`, navega para o pai, e posiciona o cursor sobre a entrada cujo `Name == originName` (cursor na pasta de origem, padrão MC). Se não achar (ex.: oculta e ocultas não exibidas), cai no 1º item real.
- **Backspace** (`NavigateToParentAsync`) mantém comportamento atual de subir; opcionalmente também pousa na origem quando chamado pelo teclado. Para manter escopo enxuto, **Backspace segue o comportamento atual** (subir; cursor no topo/1º real) — a origem é garantida pela linha `..`. Reavaliar se o usuário pedir.

**Por quê**: spec PII-08 (cursor na origem ao subir via `..`) e PII-09 (cursor no 1º real ao entrar).

### D3. Guardas de marcação no Core (`SelectionService`)

- `Toggle`: se `state.Entries[index].Name == ".."`, retorna sem marcar e **sem avançar cursor**.
- `MarkByPattern` / `UnmarkByPattern`: iteram só entradas com `Name != ".."`.
- `Invert`: só entradas com `Name != ".."`.

**Por quê**: `..` nunca pode ficar em `MarkedPaths`; todos os caminhos de marcação convergem para esses 4 métodos (MC: `panel.c:4811` `file_mark` retorna cedo p/ DOTDOT).

### D4. Fontes de operação excluem `..`

- `MainWindowViewModel.GetOperationSources` já usa `MarkedPaths` (nunca conterá `..`) OU o cursor entry. Adicionar guarda: se a entrada do cursor é `..`, tratá-la como não-selecionada (não incluir no retorno).
- Assim F5/F6/F8 sobre uma linha `..` sem marcação não abre diálogo (spec PII-12).

### D5. Ícones (camada visual)

- `PanelView.axaml` DataTemplate vira `Grid ColumnDefinitions="Auto,Auto,*,Auto"`: `PathIcon` (pasta/arquivo), marcador `*`, nome, tamanho.
- Geometria embutida como `StreamGeometry` em recurso da UserControl ou inline `Data="..."` em dois `PathIcon` com `IsVisible` ligado a `IsDirectory` (pasta) / `!IsDirectory` (arquivo). Conversor de bool p/ IsVisible via `FuncValueConverter<bool,bool>` local ou classes CSS-like com `:visible`... **decisão**: dois `PathIcon`, cada um com `Classes.folder="{Binding Entry.IsDirectory}"` usando `PseudoClasses` de visibilidade é frágil; usar um conversor simples `BoolToVisibility` no App (novo `Converters/BoolToVisibilityConverter.cs`) ou expor `IsFolder`/`IsFile` na `PanelEntryRow`.
- `PanelEntryRow` ganha propriedades derivadas `IsFolder` (= `Entry.IsDirectory`) e `IsDotDot` (= `Entry.Name == ".."`); o XAML usa `IsVisible` com conversor ou classes. Simplest: adicionar `[..]` nome com `IsDotDot` para não aplicar hover de seleção de item? — fora de escopo; manter visual neutro.
- Cor dos ícones: `Foreground="{DynamicResource ...}"` (novo token `PanelIconBrush`, ou reusar `PanelBorderBrush`/foreground do tema). **Decisão**: adicionar token `TextForegroundBrush`-like? Para enxuto, ícones usam o mesmo pincel do texto padrão via recurso Fluent (`{DynamicResource TextFillColorPrimaryBrush}` é do Fluent? não garantido). **Decisão final**: reusar `PanelBorderBrush` para ícone de pasta e `TextErrorBrush`-family NÃO — adicionar 2 tokens simples em `Themes.axaml` (`FolderIconBrush`, `FileIconBrush`) em Light e Dark, respeitando THM-05 (nenhuma cor literal em views). Teste estrutural cobre.

**Por quê**: sem asset externo; contraste por variante via paleta.

### D6. Symlink

- `BuildEntry` (Infra) já resolve: `Directory.Exists` segue symlink, então symlink→dir tem `IsDirectory=true`. Ícone segue `IsDirectory`, cobrindo PII-04 sem lógica nova.

### D7. Verificação

- **Core (unit)**: `SelectionService` — Toggle em `..` não marca e não move cursor; MarkByPattern/Invert/Unmark ignoram `..`. Local: `tests/McGui.Core.Tests/Services/SelectionServiceTests.cs`.
- **App (unit)**: `PanelViewModel` — lista não-raiz tem `..` no topo; raiz não tem; cursor entra no 1º real; `..` sobe e pousa na origem; vazio não-raiz mostra `..`; Up em `..` não passa. `MainWindowViewModel` — F5 com cursor em `..` sem marca não abre diálogo. Fakes: `FakeFileSystemService` precisa expor raiz? Testes de raiz usam `/` como diretório (Fake aceita `/` se `AddDirectory("/")`). Verificar.
- **Estrutural**: teste de tema já varre `.axaml`; garantir novos tokens em ambas variantes.
- **UAT visual**: ícones pasta/arquivo nos dois temas; `..` presente/ausente; voltar pousa na origem.

## Arquivos afetados

- `src/McGui.Core/Services/SelectionService.cs` (guardas `..`)
- `src/McGui.App/ViewModels/PanelViewModel.cs` (injeção `..`, cursor origem)
- `src/McGui.App/ViewModels/PanelEntryRow.cs` (IsFolder/IsDotDot p/ view)
- `src/McGui.App/ViewModels/MainWindowViewModel.cs` (GetOperationSources ignora `..`)
- `src/McGui.App/Views/PanelView.axaml` (+ ícones), `.axaml.cs` se precisar
- `src/McGui.App/Themes.axaml` (+ `FolderIconBrush`, `FileIconBrush` em Light/Dark)
- Testes: `SelectionServiceTests.cs`, `PanelViewModelTests.cs`, `MainWindowViewModelTests.cs`, novo `ThemeResourcesTests` p/ tokens novos
