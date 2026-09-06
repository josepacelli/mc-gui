# STATE

## Decisions

### AD-001
- **Decision**: Solução organizada em 3 projetos por responsabilidade — `McGui.Core` (modelos + interfaces, sem dependência de SO), `McGui.Infrastructure.<Plataforma>` (implementação real por SO, ex.: `McGui.Infrastructure.macOS`), `McGui.App` (Avalonia UI/ViewModels).
- **Reason**: O projeto tem como objetivo declarado ser um clone completo multiplataforma (Windows/macOS/Linux) do Midnight Commander, entregue primeiro em macOS. Isolar código específico de SO atrás de interfaces desde a primeira feature evita reescrever `Core`/`App` ao portar para as próximas plataformas.
- **Trade-off**: Mais projetos/arquivos de configuração para manter desde o início, comparado a um monolito de projeto único.
- **Scope**: Toda feature futura que envolva acesso a sistema de arquivos, diálogos nativos, ou qualquer API específica de SO deve seguir este padrão de camadas.
- **Date**: 2026-09-05
- **Status**: active

## Handoff

- **Feature**: `macos-native-chrome` (`.specs/features/macos-native-chrome/`) — **DONE**.
- **Execute**: T1-T9 (6 tasks originais + 3 fix tasks pós-Verifier) + Verifier independente **PASS** na 3ª rodada (14/14 ACs, 11 verified + 3 accepted gaps; gate 218/218; sensor 5/5) — `e52ff58`..`699daca`.
- **Completed**: 218 testes (17 Core + 31 Infra + 170 App, +38 desde a feature anterior). Working tree limpo, branch `main` (não pushed — sem go-ahead pedido/dado pro push nesta sessão).
- **Entregue**: título estendido com semáforo inline (`ApplyMacChrome()` em `MainWindow.axaml.cs`, guardado por `OperatingSystem.IsMacOS()`); `NativeMenu.Menu` espelhando a `Menu` in-window (mesmos `Command`/`CommandParameter`/`IsEnabled`); brushes nativos em `Themes.axaml` (`NativeListHoverBrush`, `NativeListSelectedBrush`, `NativeToolbarBackgroundBrush`, `NativeToolbarButtonForegroundBrush`); `IsMacOS` em `PanelViewModel`/`MainWindowViewModel` gating `Classes.native`/`Classes.fkey` na lista de arquivos e barra F1-F10.
- **Bug real pego em produção**: durante a 1ª rodada de Verifier, o usuário testou o app e reportou ao vivo (via screenshot) que estender a área do cliente sem reservar faixa de arraste quebrou o drag da janela e sobrepôs o menu aos semáforos. Corrigido reservando um `Border` (`Grid.Row="0"`, 28px, `WindowDecorationProperties.ElementRole="TitleBar"`) só no macOS, mesmo padrão `Classes.x="{Binding IsMacOS}"` do resto da feature. Confirmado visualmente pelo usuário rodando `dotnet run --project src/McGui.App`.
- **Decisões**: sem projeto `Infrastructure` novo (Avalonia já abstrai `ExtendClientAreaToDecorationsHint`/`NativeMenu`/`WindowDecorationProperties` por SO — não viola AD-001); sem zebra-striping na lista (só hover/seleção via `Style Selector` já existente); altura de 28px da faixa de título é estimativa não confirmada por API do Avalonia (lição `L-009` registrada em `.specs/LESSONS.md`).
- **Next step**: aguardando próxima feature do usuário. Backlog MC: viewer F3, editor F4, chmod/chown, links, VFS/FTP, hotlist, usermenu F2; refinamento do ícone (design); assinatura/notarização p/ distribuição pública; installers Win/Linux.
- **Blockers**: none
- **Uncommitted files**: este `STATE.md` (handoff atual).
- **Branch**: main (local à frente de origin/main — feature inteira não empurrada; pedir go-ahead antes de push).
