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

- **Features**: `panel-icons-dotdot` (**DONE**, Verifier PASS 17/17) e `mc-menubar` (**DONE**, Verifier PASS 12/12) — detalhes abaixo.
- **panel-icons-dotdot** (`.specs/features/panel-icons-dotdot/`): T1-T7 + fix gap ícone + Verifier PASS (`ee3613b`). `..` virtual no topo (exceto raiz), não-marcável, navega origem; ícones `PathIcon` pasta/arquivo; tamanhos B/kB/MB/GB/TB base 1024.
- **mc-menubar** (`.specs/features/mc-menubar/`): T1-T4 (`b89f24f`..`b3002f5`) + Verifier FAIL→Fix G1/G2 (testes estruturais) → re-verify PASS (`68d0315`). Menubar Left/File/Command/Options/Right replicando `../mc/src/filemanager/filemanager.c`; Theme movido p/ Options; F9 abre 1º menu; itens inexistentes desabilitados; novos commands de VM: `RescanActivePanel`, `SelectAll`, `UnselectAll`, `InvertSelection`.
- **Completed**: 180 testes (17 Core + 31 Infra + 132 App). Working tree limpo, branch `main`.
- **UAT notes**: app GUI às vezes falha com `Avalonia.Native -6661` (RenderTimer) ao abrir remoto via `dotnet run` — requer sessão gráfica; matar processos (`pkill -9 -f McGui`) e relançar. Usuário confirmou visualmente: feature A painéis ok, feature B menubar ok.
- **Next step**: aguardando próxima feature do usuário. Backlog MC não-implementado (desabilitado na menubar): viewer F3, editor F4, chmod/chown, links, VFS/FTP, hotlist, find-file, tree, panelize, usermenu F2, quick cd. Fluxo: `tlc-spec-driven`.
- **Blockers**: none
- **Uncommitted files**: este `STATE.md` (handoff atual).
- **Branch**: main (origin/main em `568d20e`; commits locais desde `9a97be4` NÃO pushados — requer go-ahead explícito).
