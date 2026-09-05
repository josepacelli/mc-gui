# Theming Design

> Decisão de arquitetura para a feature `theming`. Leitura complementar: `spec.md`.

## Visão geral

Sistema de tema em duas camadas: **recursos declarativos** (paleta Avalonia por variante) e **estado + controle** (ViewModel pura testável + glue na view que aplica `RequestedThemeVariant`).

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│ Recursos (XAML, declarativo)│     │ Estado (C# puro, testável)    │
│  App.axaml / Themes.axaml   │     │  ThemePreference enum         │
│  ThemeDictionaries          │     │  MainWindowViewModel          │
│  Light / Dark / Default     │     │   CurrentTheme / SetTheme /   │
│  tokens semânticos          │     │   CycleTheme / Is*Checked     │
└──────────────┬──────────────┘     └──────────────┬───────────────┘
               │ {DynamicResource}                 │ PropertyChanged
               ▼                                    ▼
        Views .axaml                        MainWindow glue (code-behind)
        (sem cor literal)                   → Application.Current.RequestedThemeVariant
```

## Decisões

### D1. Onde ficam os recursos

- Novo `src/McGui.App/Themes.axaml` (ou `Resources/Themes.axaml`) com `<ResourceDictionary>` contendo `ThemeDictionaries` (chaves `Light`, `Dark`, fallback `Default`).
- `App.axaml`: `<Application.Resources>` recebe `MergedDictionaries` → `Themes.axaml`; mantém `<FluentTheme />` em `Styles`.
- `RequestedThemeVariant="Default"` já presente em `App.axaml` — inalterado (garante seguir sistema no boot, THM-08).

**Por quê**: recurso separado permite varredura estrutural (buscar cor literal fora de `Themes.axaml`) e mantém `App.axaml` enxuto.

### D2. Tokens

8 tokens da tabela "Paleta semântica" do spec, definidos com `SolidColorBrush` por variante. `DynamicResource` em todos os views (nunca `StaticResource` — não resolve em `ThemeDictionaries`).

### D3. Estado do tema (testável sem UI)

- `enum ThemePreference { System, Light, Dark }` em `McGui.App/ViewModels` (ou namespace próprio).
- `MainWindowViewModel` ganha:
  - `[ObservableProperty] ThemePreference currentTheme` (default `System`)
  - `[RelayCommand] void SetTheme(ThemePreference p)`
  - `[RelayCommand] void CycleTheme()` — ordem System→Light→Dark→System
  - Propriedades derivadas p/ menu check: `IsSystemThemeChecked`, `IsLightThemeChecked`, `IsDarkThemeChecked` (ou converter no XAML)
- Nenhuma dependência de Avalonia runtime aqui → testável com fakes existentes.

**Por quê**: `MainWindowViewModel` já é o hub de estado da janela (painéis, comandos); adicionar tema lá mantém um único ponto de estado sem novo serviço. Ciclo em VM pura = THM-19..23 testável em xunit.

### D4. Aplicação do tema (glue na view, não testável)

- `MainWindow.axaml.cs`: ao `PropertyChanged` de `CurrentTheme`, seta `Application.Current.RequestedThemeVariant`:
  - `System` → `ThemeVariant.Default`
  - `Light` → `ThemeVariant.Light`
  - `Dark` → `ThemeVariant.Dark`
- Como diálogos não fixam `RequestedThemeVariant`, herdam do `Application` (THM edge case diálogo aberto).

**Por quê**: `Application.Current` exige runtime Avalonia; aplicar em código-behind (não em VM) preserva testabilidade. Glue é 5 linhas, validada por UAT.

### D5. MenuBar

- `MainWindow.axaml`: `Grid` ganha linha `Auto` no topo → `MenuBar` com `MenuItem Header="Theme"` e 3 `MenuItem` (`Light`/`Dark`/`System`) com `Command="{Binding SetThemeCommand}" CommandParameter="{x:Static ...}"` + `IsChecked` via propriedade da VM.
- Estilo MC: MenuBar fica sempre visível, acima dos painéis.

**Por quê**: Avalonia `MenuBar` nativo é a forma acordada com o usuário.

### D6. Tecla F12

- `GestureAction` ganha `CycleTheme`.
- `KeyGestureMap.Gestures`: `[new KeyGesture(Key.F12)] = GestureAction.CycleTheme`.
- `MainWindow.OnKeyDown`: novo `case GestureAction.CycleTheme: viewModel.CycleThemeCommand.Execute(null); break;`
- `KeyGestureMapTests` atualizado.

**Por quê**: segue o padrão de dispatch existente (mapa + switch), F12 livre.

### D7. Substituição de cores nos views

| View | Cor atual | Token |
| --- | --- | --- |
| `PanelView.axaml` estilo `.panelRoot` | `Gray` | `PanelBorderBrush` |
| `PanelView.axaml` estilo `.panelRoot.active` | `DodgerBlue` | `PanelBorderActiveBrush` |
| `PanelView.axaml` overlay loading bg | `#AA000000` | `OverlayLoadingBackgroundBrush` |
| `PanelView.axaml` overlay loading text | `White` | `OverlayLoadingForegroundBrush` |
| `PanelView.axaml` overlay dir-error bg | `#DD400000` | `OverlayErrorBackgroundBrush` |
| `PanelView.axaml` overlay dir-error text | `White` | `OverlayErrorForegroundBrush` |
| `CopyMoveDialog.axaml` erro | `Red` | `TextErrorBrush` |
| `MkdirDialog.axaml` erro | `Red` | `TextErrorBrush` |
| `DeleteConfirmDialog.axaml` aviso | `OrangeRed` | `TextWarningBrush` |

Overlays usam classes CSS-like (`IsVisible`), então o background/texto ficam via `{DynamicResource ...}` direto no `Border`/`TextBlock`.

### D8. Verificação

- **Estrutural (xunit, sem UI)**: teste que lê os `.axaml` de `src/McGui.App` (Views + MainWindow) e falha se achar cor literal (hex `#...` ou nome de cor conhecido) em propriedade visual — exceto `Themes.axaml`. Fonte da verdade: caminhos relativos resolvidos a partir da raiz do repo no teste.
- **Lógica (xunit)**: ciclo `CycleTheme` nas 4 posições, `SetTheme` seta estado, check-state das 3 opções.
- **Build-gate**: cor literal em XAML que não resolva falha no compilador XAML do Avalonia (AvaloniaXamlIl) — THM-06.
- **UAT visual**: rodar app em System/Light/Dark, abrir diálogos, conferir contraste conforme tabela.

## Fora do design

Persistência de tema, skins externas, ThemeVariantScope por painel — ver Out of Scope do spec.

## Arquivos afetados

- `src/McGui.App/Themes.axaml` (novo)
- `src/McGui.App/App.axaml`
- `src/McGui.App/MainWindow.axaml` (+ MenuBar)
- `src/McGui.App/MainWindow.axaml.cs` (+ glue tema, + case F12)
- `src/McGui.App/Views/PanelView.axaml`
- `src/McGui.App/Views/CopyMoveDialog.axaml`, `MkdirDialog.axaml`, `DeleteConfirmDialog.axaml`
- `src/McGui.App/Input/GestureAction.cs`, `KeyGestureMap.cs`
- `src/McGui.App/ViewModels/MainWindowViewModel.cs`
- Testes: `MainWindowViewModelTests.cs`, `KeyGestureMapTests.cs`, novo teste estrutural de tema
