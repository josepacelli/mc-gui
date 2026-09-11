# MC Menu Bar Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/mc-menubar/design.md`
**Status**: Draft

---

## Test Coverage Matrix

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| `McGui.App` - `McMenuDefinitions` | unit | Menus `Left`/`File`/`Command`/`Options` contêm exatamente os itens canônicos (texto sem `&`, mnemônico, ordem, separadores) extraídos do `filemanager.c`; `Right` espelha `Left`; habilitados = conjunto esperado; desabilitados incluem o conjunto do spec | `tests/McGui.App.Tests/McMenuDefinitionsTests.cs` | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - `MainWindow.axaml` | structural | Cada item do XAML corresponde às definições (habilitados têm ação/command; texto bate); Theme aparece dentro de Options; 5 menus top-level | leitura `.axaml` no teste estrutural + build-gate | `dotnet test ...` + `dotnet build McGui.sln -warnaserror` |
| `McGui.App` - theming | unit (existente) | Menu Theme movido p/ Options não quebra tests atuais de tema (VM-based) | `tests/McGui.App.Tests/ViewModels/MainWindowViewModelTests.cs` | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - XAML runtime | none | build-gate + UAT (F9, mnemonics, setas, Options>Theme, visual) | `src/McGui.App/MainWindow.axaml` | `dotnet build` + execução manual |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Tasks com testes unitários | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| Build | Tasks de XAML | `dotnet build McGui.sln -warnaserror` |
| Full | Fim de fase + feature completa | `dotnet format McGui.sln --verify-no-changes && dotnet build McGui.sln -warnaserror && dotnet test McGui.sln` |

---

## Execution Plan

```
T1
T1 -> T2
T2 -> T3
T2 -> T4
T3 -> T4
```

---

## Task Breakdown

### T1: `McMenuDefinitions` com as 4 listas canônicas

**What**: Criar `src/McGui.App/McMenuDefinitions.cs` (C# puro) modelando `McMenuItem { string Text; char? Mnemonic; bool IsSeparator; bool IsEnabled; string? CommandName; }` e `McMenu { string Name; string MnemonicHeader; IReadOnlyList<McMenuItem> Items; }`. Expor `Menus` = Left/File/Command/Options com itens canônicos extraídos do `filemanager.c` (textos sem `&`, mnemônico, separadores e ordem conforme a extração) + `Right` espelhando `Left`. Itens sem ação mc-gui têm `IsEnabled=false`. Habilitados: File Copy/Rename-Move/Mkdir/Delete/Rescan/Select group/Unselect group/Invert selection/Exit; Options Theme (adicionado); demais do File/Command/Options/Panel desabilitados. Teste `McMenuDefinitionsTests`: cada menu tem os itens certos (texto/ordem/separadores/mnemônico); Right==Left; habilitados == conjunto esperado; desabilitados incluem View/Edit/Quick cd/User menu/Directory tree/Find file/Compare dirs/Hotlist/VFS/Background jobs/Configuration/Layout/Panel options/Confirmation/Appearance/Learn keys/Virtual FS/Save setup/Quick view/Info/Tree/Panelize.
**Where**: `src/McGui.App/McMenuDefinitions.cs` (novo), `tests/McGui.App.Tests/McMenuDefinitionsTests.cs` (novo)
**Depends on**: none
**Reuses**: N/A
**Requirement**: MB-01, MB-02, MB-03, MB-05, MB-06, MB-08

**Done when**:
- [x] `McMenuDefinitions` expõe 5 menus (Left/File/Command/Options/Right), Right clonando Left
- [x] Itens/texto/ordem/separadores das 4 funções do original presentes (lista canônica embutida no teste)
- [x] Habilitação reflete ações existentes; desabilitados cobrem o conjunto do spec
- [x] Testes passam: 25 (McMenuDefinitionsTests)

**Tests**: unit (estrutura/habilitação)
**Gate**: quick

**Status**: ✅ Complete

---

### T2: `MainWindow.axaml` com 5 menus + Theme em Options

**What**: Substituir o top-level `Menu` atual (só Theme) por 5 `MenuItem` top-level: `_Left`, `_File`, `_Command`, `_Options`, `_Right`. Cada um com sub-`MenuItem` correspondente às definições (Text com mnemônico via `_`), separadores, e `IsEnabled`/`Command` para os habilitados (File Copy→RequestCopyCommand etc.). Mover o submenu Theme (System/Light/Dark, checks, SetThemeCommand) p/ dentro de `Options` (após "Appearance..."). Itens desabilitados: só `IsEnabled="False"` e texto.
**Where**: `src/McGui.App/MainWindow.axaml`
**Depends on**: T1
**Reuses**: Commands existentes da VM (RequestCopy/Move/Mkdir/Delete, SetTheme)
**Requirement**: MB-01, MB-02, MB-03, MB-04, MB-05, MB-07, MB-09

**Done when**:
- [x] 5 menus top-level na ordem; Right espelha Left
- [x] Menus File/Command/Options com itens e separadores do original; Theme dentro de Options
- [x] Habilitados ligados a commands; desabilitados inertes
- [x] `dotnet build McGui.sln -warnaserror` passa

**Tests**: none (XAML; estrutura coberta em T1/T3)
**Gate**: build

**Status**: ✅ Complete

---

### T3: Teste estrutural do XAML × definições + Regressão theming

**What**: Adicionar teste que lê `MainWindow.axaml` e confere consistência com `McMenuDefinitions` (os 5 headers presentes; cada item habilitado das definições aparece com command; o conjunto de texto dos itens bate 1:1) — de forma pragmática, validar headers e que Theme está sob Options e não top-level. Rodar suíte completa p/ garantir que mover Theme p/ Options não quebrou tests de theming (VM) nem build de bindings.
**Where**: `tests/McGui.App.Tests/McMenuDefinitionsTests.cs` (estender), repo-wide regression
**Depends on**: T2
**Reuses**: N/A
**Requirement**: MB-01, MB-03, MB-05, MB-09; regressão theming

**Done when**:
- [x] Teste estrutural passa (headers, Theme sob Options)
- [x] Full App tests verdes (incl. theming VM tests)

**Tests**: unit/structural + regression
**Gate**: quick

**Status**: ✅ Complete

---

### T4: F9 abre primeiro menu + fechamento

**What**: Em `MainWindow.OnKeyDown`, tratar `GestureAction.PullDownMenu` (F9): achar o primeiro `MenuItem` top-level (via `LogicalChildren` do `Menu` ou `x:Name`) e setar `IsSubMenuOpen=true` (abre dropdown do 1º menu). Rodar full gate. UAT: F9 abre Left; Alt+mnemônico abre menu; setas/Enter; Options>Theme alterna claro/escuro; itens desabilitados inertes. Registrar.
**Where**: `src/McGui.App/MainWindow.axaml.cs`, `src/McGui.App/MainWindow.axaml` (x:Name no Menu)
**Depends on**: T2, T3
**Reuses**: Padrão de dispatch existente no OnKeyDown
**Requirement**: MB-06, MB-10, MB-11, MB-12

**Done when**:
- [x] F9 abre o primeiro menu (Left)
- [x] Full gate verde (180 testes: 17+31+132)
- [x] UAT registrado (F9, mnemonics, Theme em Options, disabled inertes) - usuário confirmou "Tudo ok"

**Tests**: none (UAT; estrutura coberta) — full gate
**Gate**: full

**Status**: ✅ Complete

---

## Task Granularity Check

> T1 modelo puro (testável), T2 XAML (visual), T3 teste estrutural/regressão, T4 F9+fechamento. Cada task atômica com gate e commit.

## Diagram-Definition Cross-Check

> Sequência T1→T2→T3→T4; `Depends on` espelha o plano.

## Test Co-location Validation

> `McMenuDefinitionsTests.cs` em `tests/McGui.App.Tests/` espelhando o novo `McMenuDefinitions.cs`; regression via suíte existente.
