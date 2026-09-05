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

- **Feature**: `theming` (`.specs/features/theming/`) — **DONE** + 3 micro-features pós-verificação entregues inline.
- **Phase / Task**: theming Execute T1-T8 + Verifier PASS + fix M4 (detalhes em handoff anterior). Pós-DONE, usuário pediu 3 ajustes entregues como micro-features (sem artifacts próprios): (1) **navegação por mouse** `9a97be4` (single-click move cursor via SelectionChanged, duplo-clique ativa = entra em dir); (2) **barra de progresso inline no CopyMoveDialog** `b1abbbf` (PercentComplete/ProgressSummary na VM, ProgressBar no dialog, bindings re-notificados na UI thread pelo code-behind; ProgressDialog fica no código mas inativo); (3) **accent nativo macOS na borda do painel ativo** `39e211c` (MainWindow lê `PlatformColorValues.AccentColor1` em `Opened` + subscreve `ColorValuesChanged`, sobrescreve recurso da janela `PanelBorderActiveBrush`). Fix separado: **barra F-keys justificada** `06b19e0` (UniformGrid não esticava botões; trocado por Grid de 10 colunas `*` + `HorizontalAlignment=Stretch`).
- **Completed**: 124 testes (13 Core + 31 Infra + 80 App). Working tree limpo (exceto este `STATE.md`), branch `main`.
- **Decisões relevantes**: `MenuBar` não existe no Avalonia 12 (usar `Menu`); `UniformGrid` não estica filhos (usar Grid `*` + Stretch); copiar/mover roda em `Task.Run` (updates de progresso precisam re-notificação na UI thread); accent do sistema via `VisualExtensions.GetPlatformSettings(Visual).GetColorValues().AccentColor1`.
- **Next step**: aguardando próxima feature do usuário. Fluxo: `tlc-spec-driven` (Specify → Execute).
- **Blockers**: none
- **Uncommitted files**: este `STATE.md` (handoff atual).
- **Branch**: main (origin/main em `568d20e`; commits locais `9a97be4`..`39e211c` NÃO pushados — requer go-ahead explícito).
