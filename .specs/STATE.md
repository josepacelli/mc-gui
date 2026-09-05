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

- **Feature**: `dual-pane-core` (`.specs/features/dual-pane-core/`) — **DONE**.
- **Phase / Task**: Execute T1-T21 commitadas + simplify pass (8 fixes aplicados, commits `11a4a47`..`741cc7e`, decisões em `tasks.md` seção "Simplify pass") + Verifier independente **PASS** (`validation.md`, commits `83fdd31`), gate `validate_state.py` 0 erros.
- **Completed**: 108 testes (13 Core + 31 Infra + 64 App). Working tree limpo (exceto este `STATE.md`), branch `master`.
- **Gaps aceitos (não bloqueiam, registrados em `validation.md` "Ranked gaps")**: (1) semântica de symlink em Copy/Move/Delete sem teste automatizado; (4) ramo `.Trashes/<uid>` cross-volume sem verificação (limitação de ambiente T9, precisa 2º volume físico ou seam injetável no `VolumeLocator`); (5) resumo de entradas puladas nunca exibido na UI (DPC-31 "report"); (6) matriz de conflito Move (Skip/Rename/Abort) sem teoria individual; (7) spec-precision gaps informacionais. Fixes 2 (bytes de move) e 3 (delete off-thread) já fechados com testes de regressão (`1e92d9d`, `3d92359`).
- **Next step**: feature nova de theming Avalonia (pedida pelo usuário antes da pausa, NUNCA iniciada) — usar skill `ui-ux-pro-max` (guidance de design, não gera Avalonia nativo) + doc oficial `https://docs.avaloniaui.net/docs/styling/styles` pra criar `Styles`/`ResourceDictionary` do Avalonia cobrindo tema claro/escuro consistente em Mac/Windows/Linux. Passar de novo pelo fluxo `tlc-spec-driven` (Specify → Execute).
- **Blockers**: none
- **Uncommitted files**: este `STATE.md` (handoff atual).
- **Branch**: master
