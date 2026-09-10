# STATE

## Decisions

### AD-001
- **Decision**: Solução organizada em 3 projetos por responsabilidade — `McGui.Core` (modelos + interfaces, sem dependência de SO), `McGui.Infrastructure.<Plataforma>` (implementação real por SO, ex.: `McGui.Infrastructure.macOS`), `McGui.App` (Avalonia UI/ViewModels).
- **Reason**: O projeto tem como objetivo declarado ser um clone completo multiplataforma (Windows/macOS/Linux) do Midnight Commander, entregue primeiro em macOS. Isolar código específico de SO atrás de interfaces desde a primeira feature evita reescrever `Core`/`App` ao portar para as próximas plataformas.
- **Trade-off**: Mais projetos/arquivos de configuração para manter desde o início, comparado a um monolito de projeto único.
- **Scope**: Toda feature futura que envolva acesso a sistema de arquivos, diálogos nativos, ou qualquer API específica de SO deve seguir este padrão de camadas.
- **Date**: 2026-09-05
- **Status**: superseded by AD-002

### AD-002
- **Decision**: Migração para Swift/SwiftUI usa 1 Swift Package Manager package com 4 targets (`MCGuiApp`, `MCGuiCore`, `MCGuiUI`, `MCGuiMacOS`), substituindo a arquitetura de 3 projetos C# (Core, Infrastructure, App).
- **Reason**: Apps SwiftUI tipicamente usam single-package; limites de módulo via `public`/`internal`/`package` substituem limites de projeto. Camadas de Clean Architecture preservadas via dependências entre targets.
- **Trade-off**: Isolamento menos forçado que projetos separados; depende de disciplina do dev e do modificador `package`.
- **Scope**: Toda feature Swift futura neste repositório.
- **Date**: 2026-09-09
- **Status**: active

### AD-003
- **Decision**: Editor e viewer de texto usam `NSViewRepresentable` envolvendo `NSTextView` (TextKit 2); viewer de imagem/hex é SwiftUI puro.
- **Reason**: Nenhum editor de texto SwiftUI puro iguala capacidade do NSTextView; TextKit 2 dá syntax highlighting, large file handling, acessibilidade.
- **Trade-off**: Exige bridging AppKit; não é SwiftUI puro, mas só nos componentes de editor/viewer.
- **Scope**: Features de Editor e Viewer de texto.
- **Date**: 2026-09-09
- **Status**: active

### AD-004
- **Decision**: Main window carries both the native macOS menu bar (App/File/Edit/View/Go/Window/Help, `AppCommands.swift`) and a new in-window top bar reproducing the original terminal mc's `Left | File | Command | Options | Right` row; a new bottom `ButtonBar` reproduces the original's numbered F1-F10 button row; the volumes sidebar (`MainWindow`'s `VolumesSidebar`) is removed in favor of volume navigation via the new Left/Right menus.
- **Reason**: User rejected the prior layout - it lacked the original terminal app's structural chrome (top menu row, bottom button row) and added a sidebar the original never had. User explicitly chose "keep both menu bars" over replacing the native one, and explicitly confirmed removing the sidebar.
- **Trade-off**: Two menu surfaces (native + in-window) for the same actions is visual duplication, accepted deliberately for layout fidelity to the original over minimalism.
- **Scope**: `MainWindow.swift`, `PanelView.swift`, and any future feature touching the main window's chrome - see `.specs/features/classic-layout-parity/spec.md`.
- **Date**: 2026-09-10
- **Status**: active

## Handoff

- **Feature `convert-to-swift-swiftui`**: **DONE — Verifier PASS ✅ (iteração 2/3 do fix→reverify).** Histórico: Execute completou as 54 tasks originais; 1º Verifier retornou FAIL (14 requirement IDs eram código morto nunca plugado no app real — conflict dialog, Enter/Backspace/".." navigation, progress dialog, KN-04/05/06/12, FV-02/03, 3 Edge Cases). Fix cycle iteração 1 (6 commits: `9657e1e` `1ea38fd` `0232d46` `60cd903` `b20eff4` `46ce1a6`) resolveu os 6 Fix Plans; 2º Verifier achou só 1 gap residual (KN-06/Insert usava o mesmo handler do Space, nunca chamava `PanelCommands.toggleAndAdvance`). Fix iteração 2 (`2223763`) resolveu isso com `cursorID` state separado de `selection`. 3º Verifier (mesma sessão, iteração 2 do loop): **PASS**, 22/22 ACs re-derivados batem, 254/254 testes, sem gaps. `validate_state.py`: 0 erros. Relatório final: `.specs/features/convert-to-swift-swiftui/validation.md`.
- **Feature `classic-layout-parity`**: **DONE (`d7812c9`).** Layout clássico do mc original replicado: TopBar (Left/File/Command/Options/Right) + ButtonBar (F1-F10) + painéis com header/footer, sidebar de volumes removida. Aprovado via UAT interativo direto com o usuário (screenshot + "aprovado, pode commitar").
- **Pós-DONE, mesma sessão, tudo já mergeado em `main`** (merge commit `8a96752`, branch `convert-to-swift-swiftui` mantida por histórico):
  1. Remoção do projeto .NET/Avalonia legado (`88777c4`, 132 arquivos) — app é 100% Swift.
  2. Instalador (`packaging/build-macos.sh` + CI) quebrou por causa disso (chamava `dotnet publish`) — reescrito pra `swift build -c release` (`0ab4d15`), testado localmente (DMG gerado, bundle roda de verdade).
  3. Título da janela/app renomeado de "MCGui"/"MC GUI" pra "Midnight Commander" (`973d0a9`).
  4. **Bug reportado pelo usuário**: F5/F6 sempre oferecia o próprio painel como destino, não o outro (padrão dual-pane clássico) — corrigido com `PanelView.otherPanelPath` (`20dfccb`).
  5. **Bug reportado pelo usuário**: clique/duplo-clique do mouse nos painéis não funcionavam de forma confiável — 3 iterações até acertar: `.contentShape` + gesture (`86ab160`, duplo-clique ok mas simples ficou pior) → detecção por timing de `selection` (`a55e08f`, simples ok mas duplo parou de funcionar) → `NSTableView.doubleAction` nativo (`db682e6`, solução final correta — usa a mesma API que o AppKit usa pra distinguir clique simples/duplo, não compete com a seleção nativa). **Ainda não confirmado pelo usuário** (tela travou antes de testar).
  6. Fechados 3 dos "gaps pequenos" documentados como limitação conhecida: Back/Forward (`fceb268`, `PathHistoryManager` agora plugado em `PanelViewModel`) e Bookmarks (`8b2a83c` — **BookmarksView/BookmarkStore eram código morto de verdade, nunca referenciados fora do próprio arquivo**, não só "modelo local" como o STATE.md antigo dizia; agora abre via TopBar Command > Bookmarks…, persiste em disco de verdade).
- **Next step**: usuário pediu "continue" fechando gaps pequenos restantes: (a) lista de volumes no menu Go **nativo** do macOS (hoje só no TopBar Left/Right) — não iniciado; (b) usuário precisa confirmar a correção de clique/duplo-clique (item 5 acima) quando destravar a tela.
- **Blockers**: none.
- **Uncommitted files**: `.specs/LESSONS.md`/`.specs/lessons.json` (lições L-010..L-015 do ciclo de verificação) e `.specs/features/convert-to-swift-swiftui/validation.md` (relatório PASS final, untracked) — pendentes desde o merge, nunca commitados nessa branch.
- **Branch**: `main` — pushed até `8b2a83c`. `convert-to-swift-swiftui` também existe (histórico, já mergeada).

---

### Handoff history (features anteriores nesta branch/repo, para contexto)

- **Feature `macos-native-chrome`**: DONE, pushed (`699daca`).
- **Bug fix `F1/F9/F10`**: corrigido em `56c4071` (local, não pushed) — F9/F10 agora funcionam via Click; F1 desabilitado (sem Help viewer). F2 "Menu" tem o mesmo problema mas não foi tocado (fora de escopo).
- **Feature `copy-move-mc-options`**: DONE — 10 tasks, Verifier PASS, 236 testes.
- **Feature `macos-installer`**: DONE — 4 tasks, `build-macos.sh` + GitHub Actions `build-macos.yml`, DMG em `artifacts/`.
- **Feature `viewer-f3`**: PARCIAL (6/7 tasks) — T5 (Hex mode) ainda pendente na versão C#/Avalonia; **superseded** pela reescrita Swift (a feature `convert-to-swift-swiftui` cobre hex mode nativamente em FV-04/T36).

(End of file - total 18 lines)