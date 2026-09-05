# Theming Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/theming/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Camada visual XAML validada por build-gate + UAT manual no macOS (sem `Avalonia.Headless` no projeto — decisão registrada no spec). Lógica de tema testada em xunit puro sobre a ViewModel.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| `McGui.App` - estado de tema (`ThemePreference`, `MainWindowViewModel`) | unit | Ciclo System→Light→Dark→System nas 4 posições; `SetTheme` seta estado; propriedades de check-state refletem o estado | `tests/McGui.App.Tests/ViewModels/MainWindowViewModelTests.cs` | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - `KeyGestureMap`/`GestureAction` | unit | F12 presente no mapa, mapeado para `CycleTheme`, contagem de gestos consistente | `tests/McGui.App.Tests/Input/KeyGestureMapTests.cs` | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - `.axaml` views | structural scan | Nenhum `.axaml` de view/MainWindow contém cor literal (hex ou nome de cor) em propriedade visual; arquivo de paleta contém os 8 tokens em Light e Dark | novo `tests/McGui.App.Tests/Theming/ThemeResourcesTests.cs` | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - XAML runtime | none | build-gate (XAML compila) + UAT manual macOS (contraste, menu, F12, diálogos) | `src/McGui.App/**/*.axaml` | `dotnet build` + execução manual |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Tasks com apenas testes unitários de App | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| Build | Tasks de XAML/paleta | `dotnet build McGui.sln -warnaserror` |
| Full | Fim de cada fase + feature completa | `dotnet format McGui.sln --verify-no-changes && dotnet build McGui.sln -warnaserror && dotnet test McGui.sln` |

---

## Execution Plan

Fases ordenadas, execução sequencial. Diagrama de dependências (→ = "depende de"):

### Phase 1: Paleta
```
T1
```

### Phase 2: Views sem hardcoded + estado
```
T1 -> T2
T1 -> T3
T1 -> T4
```

### Phase 3: Menu e atalho
```
T4 -> T5
T4 -> T6
T4 -> T7
T5 -> T7
T6 -> T7
```

### Phase 4: Varredura estrutural + fechamento
```
T2 -> T8
T3 -> T8
T7 -> T8
```

---

## Task Breakdown

### T1: Paleta central `Themes.axaml` + merge no `App.axaml`

**What**: Criar `src/McGui.App/Themes.axaml` — `ResourceDictionary` com `ThemeDictionaries` (`Light`, `Dark`, fallback `Default`), 8 `SolidColorBrush` semânticos por variante conforme a tabela "Paleta semântica" do `spec.md`. Mesclar no `App.axaml` via `<Application.Resources><ResourceDictionary><ResourceDictionary.MergedDictionaries>`. Manter `<FluentTheme />` em `Styles` e `RequestedThemeVariant="Default"` inalterado.
**Where**: `src/McGui.App/Themes.axaml` (novo), `src/McGui.App/App.axaml`
**Depends on**: none
**Reuses**: N/A (recursos novos)
**Requirement**: THM-01, THM-02, THM-08

**Done when**:
- [x] `Themes.axaml` define os 8 tokens da tabela do spec, cada um com valor distinto em `Light` e `Dark`
- [x] Dicionário de paleta presente em arquivo standalone `Themes.axaml` mesclado no App
- [x] `App.axaml` mescla `Themes.axaml` em `Application.Resources`; `FluentTheme` e `RequestedThemeVariant="Default"` preservados
- [x] `dotnet build McGui.sln -warnaserror` passa

**Tests**: none (estrutura; varredura vem em T8)
**Gate**: build

**Status**: ✅ Complete
> SPEC_DEVIATION: sem dicionário `Default` (fallback) em `Themes.axaml`. Reason: dicionário `Default` com `StaticResource` auto-referente é circular; em runtime a variante `RequestedThemeVariant="Default"` (sistema) resolve `ActualThemeVariant` para `Light` ou `Dark`, que cobrem todos os casos. Fallback `Default` só seria necessário para variante custom desconhecida, fora do escopo. `MergeResourceInclude` (v12) usado em `Application.Resources` conforme doc oficial.

---

### T2: `PanelView.axaml` sem cores hardcoded

**What**: Substituir cores literais de `src/McGui.App/Views/PanelView.axaml` por `{DynamicResource ...}` conforme a tabela D7 do `design.md`: estilo `.panelRoot` (`Gray`→`PanelBorderBrush`), `.panelRoot.active` (`DodgerBlue`→`PanelBorderActiveBrush`), overlay loading bg (`#AA000000`→`OverlayLoadingBackgroundBrush`) + texto (`White`→`OverlayLoadingForegroundBrush`), overlay dir-error bg (`#DD400000`→`OverlayErrorBackgroundBrush`) + texto (`White`→`OverlayErrorForegroundBrush`).
**Where**: `src/McGui.App/Views/PanelView.axaml`
**Depends on**: T1
**Reuses**: N/A
**Requirement**: THM-03, THM-04, THM-05, THM-07
**Done when**:
- [x] Nenhuma cor literal (hex ou nome) resta em `PanelView.axaml` (incluindo os dois `<Style>` de borda)
- [x] Overlays de loading e erro usam tokens de fundo e de texto por variante
- [x] `dotnet build McGui.sln -warnaserror` passa

**Tests**: none (varredura em T8 cobre)
**Gate**: build

**Status**: ✅ Complete

---

### T3: Diálogos sem cores hardcoded (erro/aviso)

**What**: Substituir cores literais nos diálogos conforme tabela D7: `CopyMoveDialog.axaml` e `MkdirDialog.axaml` (`Red`→`TextErrorBrush`), `DeleteConfirmDialog.axaml` (`OrangeRed`→`TextWarningBrush`). Verificar os demais diálogos (`ConflictDialog`, `ProgressDialog`, `TextPromptDialog`) quanto a ausência de cor literal.
**Where**: `src/McGui.App/Views/CopyMoveDialog.axaml`, `MkdirDialog.axaml`, `DeleteConfirmDialog.axaml` (+ auditoria dos demais)
**Depends on**: T1
**Reuses**: N/A
**Requirement**: THM-03, THM-04, THM-05

**Done when**:
- [x] `CopyMoveDialog`/`MkdirDialog` usam `TextErrorBrush`; `DeleteConfirmDialog` usa `TextWarningBrush`
- [x] Nenhum `.axaml` de diálogo em `Views/` contém cor literal em propriedade visual
- [x] `dotnet build McGui.sln -warnaserror` passa

**Tests**: none (varredura em T8 cobre)
**Gate**: build

**Status**: ✅ Complete

---

### T4: Estado de tema na `MainWindowViewModel` (puro, testável)

**What**: Adicionar `enum ThemePreference { System, Light, Dark }` e, em `MainWindowViewModel`: `[ObservableProperty] ThemePreference currentTheme` (default `System`); `[RelayCommand] SetTheme(ThemePreference)`; `[RelayCommand] CycleTheme()` (ordem System→Light→Dark→System); propriedades somente-leitura de check-state `IsSystemThemeChecked`/`IsLightThemeChecked`/`IsDarkThemeChecked` derivadas de `CurrentTheme`. Cobertura: ciclo nas 4 posições, `SetTheme` em cada valor, check-state sincronizado, `PropertyChanged` de `CurrentTheme` e derivadas.
**Where**: `src/McGui.App/ViewModels/ThemePreference.cs` (novo), `src/McGui.App/ViewModels/MainWindowViewModel.cs`, `tests/McGui.App.Tests/ViewModels/MainWindowViewModelTests.cs`
**Depends on**: T1
**Reuses**: Padrão CommunityToolkit já usado no projeto (`[ObservableProperty]`, `[RelayCommand]`)
**Requirement**: THM-11..18 (estado/check), THM-19..23 (lógica de ciclo)

**Done when**:
- [x] `CycleTheme()` produz a sequência System→Light→Dark→System→… a partir de qualquer estado
- [x] `SetTheme(x)` define `CurrentTheme == x` e atualiza as três propriedades de check
- [x] Testes xunit passam: `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj`
- [x] Nenhuma referência a `Application.Current`/Avalonia runtime na VM (preserva testabilidade)

**Tests**: unit (ciclo, set, check-state)
**Gate**: quick

**Status**: ✅ Complete

---

### T5: Atalho F12 no `KeyGestureMap`

**What**: Adicionar `GestureAction.CycleTheme` ao enum em `src/McGui.App/Input/GestureAction.cs` e `[new KeyGesture(Key.F12)] = GestureAction.CycleTheme` a `KeyGestureMap.Gestures` em `src/McGui.App/Input/KeyGestureMap.cs`. Atualizar `tests/McGui.App.Tests/Input/KeyGestureMapTests.cs`: incluir `new KeyGesture(Key.F12)` em `RequiredGestures` e assertar o mapeamento para `CycleTheme`.
**Where**: `src/McGui.App/Input/GestureAction.cs`, `src/McGui.App/Input/KeyGestureMap.cs`, `tests/McGui.App.Tests/Input/KeyGestureMapTests.cs`
**Depends on**: T4
**Reuses**: Padrão do mapa existente
**Requirement**: THM-19, THM-20..23 (base do ciclo)

**Done when**:
- [x] F12 presente no mapa e mapeado para `CycleTheme`; contagem de `RequiredGestures` e do dicionário iguais
- [x] Testes xunit passam: `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj`

**Tests**: unit (mapa)
**Gate**: quick

**Status**: ✅ Complete

---

### T6: `MainWindow.axaml` com MenuBar + menu Theme

**What**: Adicionar `MenuBar` no topo da `MainWindow.axaml` (nova linha `Auto` no `Grid` raiz) com `MenuItem Header="Theme"` e três `MenuItem` (`Light`/`Dark`/`System`) com `Command="{Binding SetThemeCommand}"` e `CommandParameter` para cada `ThemePreference`; `IsChecked` de cada item ligado às propriedades de check-state da VM (converter inline ou `x:Static`+comparação). Bind via `DataContext` da janela (`MainWindowViewModel`).
**Where**: `src/McGui.App/MainWindow.axaml`
**Depends on**: T4
**Reuses**: N/A
**Requirement**: THM-11, THM-12, THM-13, THM-14, THM-15, THM-16, THM-17, THM-18

**Done when**:
- [x] `Menu` sempre visível no topo com menu `Theme` de 3 itens
- [x] Itens ligados a `SetThemeCommand` + check-state; nenhum cor literal adicionada
- [x] `dotnet build McGui.sln -warnaserror` passa

**Tests**: none (XAML; lógica coberta em T4, visual em UAT)
**Gate**: build

**Status**: ✅ Complete
> SPEC_DEVIATION: controle `MenuBar` não existe no Avalonia 12.1.2 (removido/renomeado). Reason: usado `Menu` (controle top-level horizontal da v12, confirmado na API `Avalonia.Controls.Menu`). Comportamento visual idêntico: barra de menu no topo com `MenuItem Header="Theme"` e sub-itens System/Light/Dark.

---

### T7: Glue de aplicação do tema + dispatch de F12

**What**: Em `src/McGui.App/MainWindow.axaml.cs`: (1) tratar `PropertyChanged` de `CurrentTheme` do DataContext e aplicar `Application.Current.RequestedThemeVariant` — `System`→`ThemeVariant.Default`, `Light`→`ThemeVariant.Light`, `Dark`→`ThemeVariant.Dark`; (2) adicionar `case GestureAction.CycleTheme:` no `OnKeyDown` chamando `viewModel.CycleThemeCommand.Execute(null)`. Remover o `case` não alcançável se houver. Usar `System/Styling` import quando necessário.
**Where**: `src/McGui.App/MainWindow.axaml.cs`
**Depends on**: T4, T5, T6
**Reuses**: Padrão de subscription a eventos do DataContext já usado (`OnDataContextChanged`)
**Requirement**: THM-13, THM-14, THM-15, THM-19, THM-20..23, edge cases (diálogo herda variante)

**Done when**:
- [x] Mudar `CurrentTheme` aplica a variante no `Application` imediatamente
- [x] F12 dispara `CycleThemeCommand`
- [x] `dotnet build McGui.sln -warnaserror` passa; `dotnet test McGui.sln` verde

**Tests**: none (glue visual; coberto por UAT)
**Gate**: full

**Status**: ✅ Complete

---

### T8: Varredura estrutural de cores hardcoded + fechamento

**What**: Criar teste xunit `tests/McGui.App.Tests/Theming/ThemeResourcesTests.cs` que (1) lê `src/McGui.App/Themes.axaml` e asserta que os 8 tokens existem nas variantes `Light` e `Dark`; (2) percorre `src/McGui.App/MainWindow.axaml` e `src/McGui.App/Views/*.axaml` (exceto o arquivo de paleta) e falha se achar cor literal (hex `#[0-9A-Fa-f]{6,8}` ou nome de cor como `Red`/`Gray`/`White`) em `Background`/`Foreground`/`BorderBrush`; (3) asserta THM-06-fallback: lista de tokens usados via `{DynamicResource ...}` nos views está contida nos tokens definidos na paleta. Resolver caminhos relativos à raiz do repo (via `AppContext.BaseDirectory` ou busca ascendente por `.sln`).
**Where**: `tests/McGui.App.Tests/Theming/ThemeResourcesTests.cs` (novo)
**Depends on**: T2, T3, T7
**Reuses**: N/A
**Requirement**: THM-05, THM-06 (fallback estrutural), THM-01, THM-02

**Done when**:
- [x] Teste falha se qualquer `.axaml` de view/MainWindow contiver cor literal em propriedade visual
- [x] Teste falha se token usado nos views não estiver definido na paleta
- [x] Full gate verde: `dotnet format McGui.sln --verify-no-changes && dotnet build McGui.sln -warnaserror && dotnet test McGui.sln` (119 testes: 13+31+75)
- [x] UAT manual macOS: rodar app em System/Light/Dark (menu + F12), abrir diálogos, conferir contraste conforme tabela do spec

**Tests**: unit/structural scan
**Gate**: full

**Status**: ✅ Complete

---

## Task Granularity Check

> Verificação de granularidade: cada task é atômica (uma unidade de mudança com gate próprio). Tasks de XAML separadas por view (T2 painel, T3 diálogos) — nenhuma task mistura paleta+views+controle. T8 é teste puro (sem mudança de código de produção). Nenhuma task < 5 min nem > 2h estimada.

## Diagram-Definition Cross-Check

> O grafo "Depends on" acima espelha o Execution Plan. Sequência válida: fase 1 → fase 2 → fase 3 → fase 4. Cada dependência declarada é real e o diagrama de cada fase lista exatamente as arestas `Depends on` das tasks que ela contém.

## Test Co-location Validation

> Testes unitários em `tests/McGui.App.Tests/` espelhando `src/McGui.App/` (Input→Input, ViewModels→ViewModels). Teste estrutural em `Theming/` (novo assunto). Nenhum teste em `Core`/`Infrastructure` — feature é 100% camada App.
