# Panel Icons + ".." Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/panel-icons-dotdot/design.md`
**Status**: Draft

---

## Test Coverage Matrix

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| `McGui.Core` - `SelectionService` | unit | `..` nunca marcado: Toggle no índice do `..` não marca nem move; MarkByPattern/Unmark/Invert ignoram `..`; entradas reais inalteradas | `tests/McGui.Core.Tests/Services/SelectionServiceTests.cs` | `dotnet test tests/McGui.Core.Tests/McGui.Core.Tests.csproj` |
| `McGui.App` - formatação de tamanho | unit | Base 1024; B/kB/MB/GB/TB; dir e `..` vazio; 0 B; 1 casa decimal máxima; limites exatos (1024 → `1 kB`) | novo teste do formatter | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - `PanelViewModel` | unit | Lista não-raiz tem `..` no topo; raiz não tem; cursor entra no 1º real; `..` (Enter/ativar) sobe e pousa na origem; diretório vazio não-raiz mostra `..`; Up em `..` não passa | `tests/McGui.App.Tests/ViewModels/PanelViewModelTests.cs` | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - `MainWindowViewModel` | unit | Fontes de operação nunca incluem `..` (cursor em `..` sem marca não abre F5/F6/F8) | `tests/McGui.App.Tests/ViewModels/MainWindowViewModelTests.cs` | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - tema | structural | Novos tokens de ícone definidos em Light e Dark no `Themes.axaml`; nenhuma cor literal adicionada em views | `tests/McGui.App.Tests/Theming/ThemeResourcesTests.cs` | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - XAML runtime | none | build-gate + UAT visual macOS (ícones, `..`, tema claro/escuro, tamanhos) | `src/McGui.App/**/*.axaml` | `dotnet build` + execução manual |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Tasks com apenas testes unitários (Core ou App) | `dotnet test tests/<Projeto>.Tests/<Projeto>.Tests.csproj` |
| Build | Tasks de XAML/tema/VM que compilam | `dotnet build McGui.sln -warnaserror` |
| Full | Fim de fase + feature completa | `dotnet format McGui.sln --verify-no-changes && dotnet build McGui.sln -warnaserror && dotnet test McGui.sln` |

---

## Execution Plan

Fases ordenadas; dentro de cada fase as tasks rodam em ordem numérica.

### Phase 1: Núcleo - `..` não marcável
```
T1
```

### Phase 2: Painel - injeção de `..`, cursor e tamanho formatado
```
T1 -> T2
T2 -> T3
```

### Phase 3: Fontes de operação + tokens de ícone
```
T2 -> T4
T4 -> T5
```

### Phase 4: Ícones no XAML
```
T5 -> T6
```

### Phase 5: Estados de borda e fechamento
```
T3 -> T7
T6 -> T7
T7 -> T8
```

---

## Task Breakdown

### T1: `SelectionService` ignora entrada `..`

**What**: Em `src/McGui.Core/Services/SelectionService.cs`, adicionar guardas: `Toggle` retorna cedo (sem marcar, sem mover cursor) quando `state.Entries[index].Name == ".."`; `MarkByPattern`/`UnmarkByPattern`/`Invert` pulam entradas `Name == ".."`. Testes: Toggle no índice do `..` não marca nem avança; invert não marca `..`; pattern `*` não marca `..`; reais continuam funcionando.
**Where**: `src/McGui.Core/Services/SelectionService.cs`, `tests/McGui.Core.Tests/Services/SelectionServiceTests.cs`
**Depends on**: none
**Reuses**: N/A
**Requirement**: PII-10, PII-11, PII-13

**Done when**:
- [x] Toggle sobre `..` deixa `MarkedPaths` sem o path do `..` e `CursorIndex` inalterado
- [x] Invert/pattern/unmark não marcam nem desmarcam `..`
- [x] Testes Core passam: `dotnet test tests/McGui.Core.Tests/McGui.Core.Tests.csproj` (17)

**Tests**: unit (guarda `..`)
**Gate**: quick

**Status**: ✅ Complete

---

### T2: `PanelViewModel` injeta `..` e posiciona cursor (entrar/sair)

**What**: Em `src/McGui.App/ViewModels/PanelViewModel.cs`: (1) em `ApplyLoadedState`, decidir se adiciona `..` (`Path.GetDirectoryName` do diretório atual não-nulo) e, quando adiciona, inserir `new FileEntry("..", parent, IsDirectory: true, ...)` no topo de `_state.Entries`; (2) `ActivateCursorEntryAsync`: se entry `Name == ".."` → guardar `originName`, navegar p/ pai, depois posicionar cursor na entrada com `Name == originName` (senão 1º real); (3) navegação descendente pousa cursor no 1º item real (índice 0 se sem `..`, 1 se com); (4) clamps de Up/Down já cobrem borda. Testes: lista não-raiz `..` no topo; raiz sem `..`; ativar `..` sobe e pousa na origem; entrar em subdir pousa no 1º real.
**Where**: `src/McGui.App/ViewModels/PanelViewModel.cs`, `tests/McGui.App.Tests/ViewModels/PanelViewModelTests.cs`
**Depends on**: T1
**Reuses**: N/A
**Requirement**: PII-05, PII-06, PII-07, PII-08, PII-09; edge cases (raiz, vazio, Up)

**Done when**:
- [x] `..` presente no topo p/ dir não-raiz; ausente na raiz
- [x] Ativar `..` navega ao pai e cursor pousa na pasta de origem
- [x] Entrar em diretório pousa cursor no 1º item real (não em `..`)
- [x] Testes App passam (82)

**Tests**: unit (lista, cursor, navegação)
**Gate**: quick

**Status**: ✅ Complete

---

### T3: Formatação de tamanho (kB/MB/GB/TB, base 1024)

**What**: Criar formatador de tamanho (ex.: `FileSizeFormatter` em `McGui.App` ou método em `PanelEntryRow`) que: bytes < 1024 → `N B`; senão divide por 1024 até < 1024 e formata `kB`/`MB`/`GB`/`TB`; valor exato de unidade sem parte fracionária (`1024` → `1 kB`, não `1.0 kB`); não-inteiro com no máximo 1 casa decimal (`1.5 MB`); `0` → `0 B`. Expor em `PanelEntryRow` uma propriedade `DisplaySize`/`SizeText`: vazia quando `IsDirectory` (inclui `..`), formatada quando arquivo. Testes unitários do formatador cobrindo B/kB/MB/GB/TB, limites exatos, 0 B, 1 casa decimal.
**Where**: novo `src/McGui.App/FileSizeFormatter.cs` (ou junto à row), `src/McGui.App/ViewModels/PanelEntryRow.cs`, novo teste (ex.: `tests/McGui.App.Tests/FileSizeFormatterTests.cs`)
**Depends on**: T2
**Reuses**: N/A
**Requirement**: PII-14, PII-15, PII-16, PII-17; edge (0 B)

**Done when**:
- [x] Formatador cobre B/kB/MB/GB/TB com base 1024 e ≤1 casa decimal
- [x] `SizeText` vazio para diretório/`..`; formatado para arquivo (propriedade a consumir em T4/T6)
- [x] Testes passam (13)

**Tests**: unit (formatação)
**Gate**: quick

**Status**: ✅ Complete

---

### T4: Fontes de operação ignoram `..` + row expõe flags

**What**: Em `src/McGui.App/ViewModels/PanelEntryRow.cs`, expor `IsFolder => Entry.IsDirectory`, `IsFile => !Entry.IsDirectory`, `IsDotDot => Entry.Name == ".."`, `SizeText` (de T3). Em `src/McGui.App/ViewModels/MainWindowViewModel.cs` `GetOperationSources`: cursor sobre `..` sem marcação retorna vazio (não abre F5/F6/F8); nunca incluir entrada `Name == ".."` nos sources. Testes: F5 com cursor em `..` sem marca não abre; sources com marcação só entradas reais.
**Where**: `src/McGui.App/ViewModels/PanelEntryRow.cs`, `src/McGui.App/ViewModels/MainWindowViewModel.cs`, `tests/McGui.App.Tests/ViewModels/MainWindowViewModelTests.cs`
**Depends on**: T2
**Reuses**: N/A
**Requirement**: PII-12, PII-13

**Done when**:
- [x] Flags e `SizeText` expostos na row
- [x] F5/F6/F8 com cursor em `..` e sem marca não abrem diálogo
- [x] Operação com marcação nunca lista `..` como source
- [x] Testes App passam (97)

**Tests**: unit (sources)
**Gate**: quick

**Status**: ✅ Complete

---

### T5: Tokens de cor de ícone na paleta

**What**: Em `src/McGui.App/Themes.axaml`, adicionar nas variantes `Light` e `Dark` os tokens `FolderIconBrush` e `FileIconBrush` com valores de contraste por variante (ex.: Light `#5F6368`/`#1967D2`; Dark `#9AA0A6`/`#8AB4F8`). Atualizar `ExpectedTokens` em `tests/McGui.App.Tests/Theming/ThemeResourcesTests.cs` com os 2 novos tokens (garante presença nas duas variantes e distinctness).
**Where**: `src/McGui.App/Themes.axaml`, `tests/McGui.App.Tests/Theming/ThemeResourcesTests.cs`
**Depends on**: T4
**Reuses**: N/A (tokens novos)
**Requirement**: PII-02 (cores por variante); integra com theming existente

**Done when**:
- [x] `FolderIconBrush` e `FileIconBrush` definidos em Light e Dark com valores distintos entre variantes
- [x] `ExpectedTokens` atualizado; teste estrutural passa
- [x] `dotnet build McGui.sln -warnaserror` passa

**Tests**: structural (tokens)
**Gate**: build

**Status**: ✅ Complete

---

### T6: Ícones + tamanho formatado no `PanelView` DataTemplate

**What**: Em `src/McGui.App/Views/PanelView.axaml`, alterar o `DataTemplate` p/ `Grid ColumnDefinitions="Auto,Auto,*,Auto"`: `PathIcon` de pasta (visível quando `IsFolder`) e `PathIcon` de arquivo (visível quando `IsFile`), com `Foreground` por tipo (`FolderIconBrush`/`FileIconBrush`); marcador `*`; nome; tamanho `Text="{Binding SizeText}"`. Geometria embutida `Data="M..."` (paths simples de folder e de file). Nenhuma cor literal.
**Where**: `src/McGui.App/Views/PanelView.axaml`
**Depends on**: T5
**Reuses**: N/A
**Requirement**: PII-01, PII-03, PII-04, PII-14, PII-15

**Done when**:
- [ ] DataTemplate exibe ícone pasta p/ `IsFolder`, arquivo p/ `IsFile`
- [ ] `..` usa ícone de pasta (PII-03); coluna de tamanho mostra `SizeText` (vazio p/ dir)
- [ ] Nenhuma cor literal em `PanelView.axaml`
- [ ] `dotnet build McGui.sln -warnaserror` passa

**Tests**: none (XAML; varredura em T8, visual em UAT)
**Gate**: build

**Status**: ⬜ Pending

---

### T7: Estados de borda (raiz/vazio/Up) + verificação de operações com marcação mista

**What**: Garantir via testes e correções em `PanelViewModel` e `MainWindowViewModel`: (a) diretório raiz sem `..`, cursor no 1º real; (b) diretório vazio não-raiz mostra `..` como única linha e ativá-lo sobe p/ origem; (c) navegação à raiz por `..` sucessivos; (d) Up em `..` não passa; (e) marcar reais com `..` presente na lista → sources exatamente as reais (nunca o pai). Ajustar onde necessário.
**Where**: `src/McGui.App/ViewModels/PanelViewModel.cs`, `src/McGui.App/ViewModels/MainWindowViewModel.cs`, testes correspondentes
**Depends on**: T3, T6
**Reuses**: N/A
**Requirement**: edge cases (raiz, vazio, Up), PII-12, PII-13

**Done when**:
- [ ] Testes de raiz, vazio, Up e navegação à raiz passam
- [ ] Teste de marcação mista com `..` presente passa (sources = reais)
- [ ] Nenhuma regressão nos testes existentes

**Tests**: unit (edge + sources)
**Gate**: quick

**Status**: ⬜ Pending

---

### T8: Fechamento estrutural + UAT

**What**: Rodar full gate (`format --verify-no-changes && build -warnaserror && test`). Confirmar varredura de tema e ausência de cor literal. UAT manual macOS: ícones pasta/arquivo em claro/escuro, `..` presente/ausente na raiz, duplo-clique e Enter navegando, cursor na origem ao voltar, tamanhos kB/MB/GB/TB, pastas/`..` sem tamanho. Registrar resultado.
**Where**: repo-wide + UAT
**Depends on**: T7
**Reuses**: N/A
**Requirement**: todas (fechamento)

**Done when**:
- [ ] Full gate verde
- [ ] UAT confirma ícones, `..`, cursor origem, raiz, tamanhos formatados
- [ ] Registro no tasks.md

**Tests**: full suite + UAT
**Gate**: full

**Status**: ⬜ Pending

---

## Task Granularity Check

> Tasks atômicas: T1 núcleo; T2 injeção+navegação; T3 formatação; T4 sources+flags; T5 tokens; T6 ícones/tamanho XAML; T7 edge states; T8 fechamento. Cada task com gate e commit próprios; sem mistura de camadas desnecessária.

## Diagram-Definition Cross-Check

> Grafo do Execution Plan espelha `Depends on`. Sequência real: T1→T2→{T3,T4}; T4→T5→T6; {T3,T6}→T7→T8. T3 e T4 dependem de T2 (painel injeta `..`); T5 depende de T4 (flags prontas p/ contexto); T6 depende de T5 (tokens existem antes do XAML usá-los); T7 precisa de T3 (SizeText) e T6 (XAML final); T8 fecha.

## Test Co-location Validation

> Testes Core em `tests/McGui.Core.Tests` (SelectionService); App em `tests/McGui.App.Tests` (ViewModels espelhando src, formatter novo, + Theming p/ tokens). Sem testes de Infra (não muda).
