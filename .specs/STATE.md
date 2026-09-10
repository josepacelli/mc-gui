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

## Handoff

- **Feature `convert-to-swift-swiftui`**: **Execute DONE — todas as 54 tasks (T1-T54, 13 fases) implementadas, testadas e commitadas.** `swift build && swift test`: 225 testes verdes. `spec.md` traceability: 93/93 requirement IDs mapeados (28 Verified, 65 Implementing). App real: `swift run MCGuiApp` abre janela "MCGui" com menu bar completo (App/File/Edit/View/Go/Window/Help), F3-F8 funcionais via teclado no painel. 8 batches de sub-agent (~7 tasks cada) rodaram sequencialmente nesta sessão; 1 interrupção por rate limit no meio do batch 5 (T35), retomada sem redoing (implementação preservada, só faltava teste+commit).
- **Verificação**: Verifier retornou **FAIL ❌** (chegou depois da sessão já ter sido pausada). Relatório completo: `.specs/features/convert-to-swift-swiftui/validation.md`. Spec-anchored: 62/93 ACs batem limpo; sensor de discriminação 3/3 mutações mortas (testes existentes são de boa qualidade onde existem). Gaps reais encontrados (código morto/nunca plugado, não só falta de XCUITest):
  1. **FO-05..09 conflict dialog é dead code** — `PanelView.performCopyMove` nunca chama `CopyMovePlanner` nem mostra `ConflictDialog`; F5/F6 real sobrescreve silenciosamente (`FileSystemServiceImpl.swift:218-234`).
  2. **FS-04/FS-05/KN-11 (Enter entra em pasta, Backspace sobe) não existem em lugar nenhum** — usuário não consegue navegar por subpastas no app real, só via Go menu/sidebar.
  3. **FO-14/FO-16 progress dialog é dead code** — nenhum `AsyncStream<OperationProgress>` existe.
  4. **KN-02..06/KN-12 (`PanelCommands`/`KeyboardShortcuts.swift`) nunca instalados em `AppEntry.commands`** — Cmd+Arrow (KN-04) e Insert (KN-06) sem caminho funcional nenhum.
  5. **FV-02 marcado "Verified" indevidamente** — sem syntax highlighting nem números de linha no `ViewerWindow` (ED-02 irmão foi corretamente flagado, esse não).
  6. Menor: FV-03 sem zoom/pan de imagem; 3 dos 7 Edge Cases do spec.md sem tratamento (paginação 10k+ entradas, cancelamento por ejeção de volume, limite de tamanho de path).
  3 lições candidatas gravadas (L-010, L-011, L-012). As 6 limitações já conhecidas/aceitas (ver acima) foram todas reconfirmadas como verdadeiras, não contam como gaps novos.
- **Limitações conhecidas e já documentadas** (não são bugs, são fronteiras de escopo aceitas, com `SPEC_DEVIATION` inline no código): (1) sem projeto/scheme Xcode ainda → XCUITest não roda, tasks `e2e` usam `swift build`/`swift test` como gate; (2) menu bar (não tecla física) pra copy/move/view/edit/delete ainda não pega seleção ativa do painel (F3-F8 físicos funcionam via `PanelView.onKeyPress`); (3) Go menu Back/Forward no-op (`PathHistoryManager` não plugado em `PanelViewModel`); (4) volume list (T51) vive num `Menu("Go")` dentro de `MainWindow.swift`, não no menu bar AppKit real; (5) Bookmarks (T54) usa modelo/closures locais em vez de importar `BookmarkStore` (MCGuiMacOS) direto — mesma restrição cross-target que F3/F4 tinha antes do T50 resolver.
- **Next step**: Verifier retornou FAIL — rotear os 6 gaps rankeados acima pra fix tasks (prioridade: #2 navegação Enter/Backspace é o mais grave, bloqueia uso real do app; depois #1 conflict dialog, #4 keyboard shortcuts não instalados, #3 progress dialog, #5 corrigir status FV-02 no spec.md, #6 menor). Ciclo fix→reverify tem limite de 3 iterações antes de escalar pro usuário. Sessão pausada a pedido do usuário antes de começar os fixes — aguardando "continuar".
- **Blockers**: none.
- **Uncommitted files**: none — árvore de trabalho limpa (último commit local: `988e454`, housekeeping de `.gitignore`/`design.md`/`STATE.md`).
- **Branch**: `convert-to-swift-swiftui`, 55 commits locais à frente de `main` (54 da feature + 1 housekeeping) — nada pushed, pedir go-ahead antes.

---

### Handoff history (features anteriores nesta branch/repo, para contexto)

- **Feature `macos-native-chrome`**: DONE, pushed (`699daca`).
- **Bug fix `F1/F9/F10`**: corrigido em `56c4071` (local, não pushed) — F9/F10 agora funcionam via Click; F1 desabilitado (sem Help viewer). F2 "Menu" tem o mesmo problema mas não foi tocado (fora de escopo).
- **Feature `copy-move-mc-options`**: DONE — 10 tasks, Verifier PASS, 236 testes.
- **Feature `macos-installer`**: DONE — 4 tasks, `build-macos.sh` + GitHub Actions `build-macos.yml`, DMG em `artifacts/`.
- **Feature `viewer-f3`**: PARCIAL (6/7 tasks) — T5 (Hex mode) ainda pendente na versão C#/Avalonia; **superseded** pela reescrita Swift (a feature `convert-to-swift-swiftui` cobre hex mode nativamente em FV-04/T36).

(End of file - total 18 lines)