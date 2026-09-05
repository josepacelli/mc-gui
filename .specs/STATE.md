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

- **Feature**: `theming` (`.specs/features/theming/`) — **DONE**.
- **Phase / Task**: Execute T1-T8 commitadas (`50fa1ad`..`5e7715a`, 10 commits) + Verifier independente **PASS** (`validation.md`, 23/23 ACs, sensor 4/6 kill, 2 survivors em zona UAT/build declarada) + fix-gap M4 (`d1050be`, distinctness Light≠Dark) + gate `validate_state.py` 0 erros.
- **Completed**: 120 testes (13 Core + 31 Infra + 76 App). Working tree limpo (exceto este `STATE.md`), branch `main`.
- **Gaps aceitos (não bloqueiam)**: (M5) glue `ApplyTheme` (MainWindow.axaml.cs) sem teste unit — zona UAT declarada, sem `Avalonia.Headless` (decisão do usuário); (M6) variante boot `Default` no `App.axaml` sem assert automatizado — declarativa + UAT; Fix 2 (THM-06 wording) já resolvido no spec. 3 lições candidates em `.specs/lessons.json` aguardando review (MenuBar→Menu v12, distinctness, THM-06 enforcement).
- **Decisões de implementação**: `MenuBar` NÃO existe no Avalonia 12 — usado `Menu` top-level; `Themes.axaml` sem dicionário `Default` fallback (Default do sistema resolve p/ Light/Dark); `MergeResourceInclude` (v12) p/ mesclar paleta.
- **Next step**: aguardando próxima feature do usuário. Features previstas no backlog de `dual-pane-core`: editor F4, viewer F3, persistência de tema, skins, hotlist. Pré-requisito p/ qualquer feature nova: passar pelo fluxo `tlc-spec-driven` (Specify → Execute).
- **Blockers**: none
- **Uncommitted files**: este `STATE.md` (handoff atual).
- **Branch**: main (origin/main configurado; último push manual do usuário. Push de novos commits NÃO feito — requer go-ahead explícito).
