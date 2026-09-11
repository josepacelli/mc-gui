# MC Menu Bar Design

> Decisão de arquitetura para a feature `mc-menubar` (fatia B). Leitura complementar: `spec.md`.

## Visão geral

Menubar superior replicando o MC original. Duas camadas:
1. **Modelo de dados puro** (`McMenuDefinitions` + helpers) que descreve menus/itens/separadores/habilitados — fonte única e testável 1:1 contra o `filemanager.c`.
2. **XAML estático** na `MainWindow` que declara os `MenuItem` com bind a comandos existentes; itens sem função ficam com `IsEnabled=False`; F9 aciona o primeiro menu via code-behind.

```
McMenuDefinitions.cs  (C# puro: menus, itens, ordem, separadores, habilitação)
        │  usado por
        ├── Teste estrutural (1:1 com lista canônica extraída do filemanager.c)
        └── (referência p/ humano conferir MainWindow.axaml)
MainWindow.axaml      Menu estático, ~50 MenuItem, IsEnabled + Command
MainWindow.axaml.cs   F9 → abre 1º menu; mnemonics via Header "&X"
```

## Decisões

### D1. Por que XAML estático + modelo de dados, não ItemsSource dinâmico

- Menus aninhados (submenu com itens) em Avalonia usam `MenuItem` tipado; gerar por `ItemsSource`+DataTemplate p/ submenus é frágil e perde bind tipado de commands.
- `McMenuDefinitions.cs` expõe as 4 listas canônicas (itens por menu, com `Text` sem `&`, `Mnemonic`, `IsEnabled`, `ActionName` opcional) + espelho Right=Left. O **teste estrutural** garante que as definições batem com a lista extraída do `filemanager.c` (texto/ordem/separador) e com o conjunto habilitado esperado (spec MB-05..08).
- O XAML não duplica lógica: apenas declara MenuItems; o teste valida contra `McMenuDefinitions` que as strings/itens no XAML correspondem (via leitura do `.axaml`). Isso mantém "código como fonte única".

### D2. Estrutura dos menus (do `filemanager.c`)

| Menu | Itens (ordem) | Fonte |
| --- | --- | --- |
| `Left` | Listing format..., Sort order..., Filter..., Encoding..., (sep), Rescan, (sep), Quick view, Info, Tree, Panelize | `create_panel_menu` |
| `File` | View, View file..., Filtered view, (sep via próximo), Edit, Copy, chmod, Link, Symlink, Relative symlink, Edit symlink, chown, Advanced chown, chattr, Rename/Move, Mkdir, Delete, Quick cd, (sep), Select group, Unselect group, Invert selection, (sep), Exit | `create_file_menu` |
| `Command` | User menu, Directory tree, Find file, Swap panels, Switch panels on/off, Compare directories, Compare files, External panelize, Show directory sizes, (sep), Command history, Viewed/edited files history, Directory hotlist, Active VFS list, Background jobs, Screen list, (sep), Edit extension file, Edit menu file, Edit highlighting group file | `create_command_menu` |
| `Options` | Configuration..., Layout..., Panel options..., Confirmation..., Appearance..., Learn keys..., Virtual FS..., (sep), Save setup, (sep), About..., (sep), Theme | `create_options_menu` + Theme adicionado |

> **Atenção — exatidão**: itens exatos (texto com `&`, ordem, separadores) serão extraídos diretamente das funções do `filemanager.c` durante a implementação; a tabela acima é o esqueleto. O arquivo `../mc` está fora do repo do mc-gui (não versionado aqui) — o **teste estrutural embute a lista canônica copiada** (fonte: `../mc/src/filemanager/filemanager.c`) e serve de guarda contra drift.

### D3. Habilitação (mapeamento p/ ações mc-gui)

Habilitados (têm ação equivalente):
- `File > Copy` (F5) → `RequestCopyCommand`
- `File > Rename/Move` (F6) → `RequestMoveCommand`
- `File > Mkdir` (F7) → `RequestMkdirCommand`
- `File > Delete` (F8) → `RequestDeleteCommand`
- `File > Rescan` → refresh painel ativo (`activePanel.RefreshCommand`)
- `File > Select group` / `Unselect group` / `Invert selection` → marcar por padrão/unselect/inverter (`MarkByPattern("*")`, `UnmarkByPattern("*")`, `InvertMarks`)
- `File > Exit` → fechar janela (F10)
- `Options > Theme` → submenu System/Light/Dark (reuso `SetThemeCommand` + check-state)
- (Swap panels se existir: hoje Tab troca ativo — não "swap"). Sem swap → desabilitado.

Desabilitados (features futuras): View/Edit/chmod/chown/links/chattr/Quick cd, todo Command menu (usermenu/tree/find/compare/hotlist/VFS/jobs/history/edit-files), Options de config (Configuration/Layout/Panel/Confirmation/Appearance/Learn keys/Virtual FS/Save setup), Quick view/Info/Tree/Panelize do Left/Right.

IsEnabled vem de `IsEnabled` do item em `McMenuDefinitions` (por `ActionName != null`) e refletido no XAML.

### D4. F9 e mnemônicos

- F9 já existe como `GestureAction.PullDownMenu` no mapa. No `MainWindow.OnKeyDown`, tratar: encontrar o primeiro `MenuItem` top-level (ex.: nome `x:Name` ou `LogicalChildren` do `Menu`) e setar `IsSubMenuOpen = true`.
- Mnemônicos: `Header="_File"` etc. (Avalonia usa `_` como prefixo de mnemônico; Alt abre). Confirmar durante implementação; se `_` não renderizar underline/mnemônico na v12, usar `&`? Avalonia usa `_`. Texto sem mnemônico usa `Header` normal.
- `McMenuDefinitions` guarda `Text` sem o prefixo e `Mnemonic` separado p/ o teste comparar com o original (`&File` → Text=File, Mnemonic=F).

### D5. Options > Theme

- `MainWindow.axaml`: mover o submenu Theme (System/Light/Dark com check + `SetThemeCommand`) do top-level p/ dentro do `Options` menu, logo antes dos separadores finais (após Appearance ou perto de About — decidir ordem na implementação seguindo "Appearance..." e antes de "Save setup").
- Bindings de check-state/commands inalterados (VM já os expõe); testes de theming (VM) não dependem do XAML → continuam verdes.

### D6. Verificação

- **Estrutural/unit (novo)**: `McMenuDefinitionsTests` — cada menu tem os itens canônicos (texto/ordem/separadores) da lista embutida do `filemanager.c`; `Right` espelha `Left`; itens habilitados exatamente o conjunto esperado; itens desabilitados incluem os listados no spec. Opcional: ler `MainWindow.axaml` e conferir que cada item habilitado tem `Command`/é `IsEnabled="False"` consistente.
- **App (VM)**: sem mudança (commands existem) — regressão via suíte atual.
- **Build/UAT**: render visual, F9, Alt-mnemonics, setas/Enter; theming via Options>Theme.

## Arquivos afetados

- novo `src/McGui.App/McMenuDefinitions.cs` (dados puros)
- novo `tests/McGui.App.Tests/McMenuDefinitionsTests.cs`
- `src/McGui.App/MainWindow.axaml` (5 menus, Theme→Options)
- `src/McGui.App/MainWindow.axaml.cs` (F9 abre 1º menu; import se necessário)
