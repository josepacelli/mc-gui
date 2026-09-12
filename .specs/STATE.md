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

### AD-005
- **Decision**: Localização usa `.strings` clássicos (não `.xcstrings`/String Catalog) por target (`MCGuiUI`, `MCGuiApp`, `MCGuiMacOS`), um `Resources/<lang>.lproj/Localizable.strings` por idioma, resolvidos via `Bundle.module` de cada target. Chaves namespaced (`tela.elemento.nome`), nunca o texto em inglês literal como chave. Strings com parâmetro usam `NSLocalizedString` + `String(format:)` com `%1$d`/`%2$@` (não a forma `String(localized: "texto \(x)")`, que usa o texto interpolado como chave). Erros tipados ganham `LocalizedError` no próprio target onde são definidos (`FileSystemServiceError` em `MCGuiMacOS`), preservando a fronteira do AD-002 (MCGuiUI nunca importa MCGuiMacOS). Detecção de tradução faltando é um teste `swift test` (diff de chaves entre os 4 `.lproj` de cada target), não ferramenta do Xcode.
- **Reason**: `.strings` é editável à mão sem risco de JSON malformado do String Catalog (não há Xcode interativo nesta sessão); mecanismo nativo da Apple pra negociação de idioma e fallback pro inglês evita reinventar essa lógica; teste de cobertura de chaves se encaixa no padrão já existente do projeto de gates via `swift test`/scripts.
- **Trade-off**: Sem a UI de estado de tradução do Xcode (pending/translated/stale) — compensado pelo teste de diff de chaves.
- **Scope**: Toda feature futura que adicionar string visível ao usuário.
- **Date**: 2026-09-10
- **Status**: active

### AD-006
- **Decision**: Quando uma feature precisa invocar uma ferramenta de linha de comando externa (ex.: `zip`) e os argumentos são inteiramente conhecidos em tempo de design (não texto arbitrário fornecido pelo usuário), a invocação usa `Process` com `arguments: [String]` (array) direto no binário (ex.: `/usr/bin/zip`), nunca `/bin/sh -c` com string interpolada. Isso é mais estrito que o único precedente existente no repo (`UserMenuRunner.swift`, que usa `/bin/sh -c` porque executa comandos de shell arbitrários definidos pelo usuário no User Menu, e foi endurecido via shell-escaping do valor interpolado em `ee5e610` — escaping é necessário ali, mas continua passando por um shell).
- **Reason**: Array de argumentos elimina estruturalmente a classe de bug de shell-injection, independente de caracteres em nomes de arquivo — não há shell pra escapar contra. Quando os argumentos são fixos/controlados (flags + paths), não há motivo pra pagar o custo de correção de escaping que o `UserMenuRunner` precisa pagar.
- **Trade-off**: Não serve para o caso do `UserMenuRunner` (que precisa mesmo de um shell pra interpretar comandos arbitrários do usuário) — este AD cobre apenas invocações novas com argumentos conhecidos em design-time, não substitui o padrão existente lá.
- **Scope**: Toda feature futura que invoque uma ferramenta CLI externa com argumentos conhecidos em tempo de design (não comandos de usuário arbitrários). Primeiro uso: `FileSystemServiceImpl.zip` (feature `context-menu-actions`).
- **Date**: 2026-09-11
- **Status**: active

## Handoff

- **Feature `convert-to-swift-swiftui`**: **DONE — Verifier PASS ✅ (iteração 2/3 do fix→reverify).** Histórico: Execute completou as 54 tasks originais; 1º Verifier retornou FAIL (14 requirement IDs eram código morto nunca plugado no app real — conflict dialog, Enter/Backspace/".." navigation, progress dialog, KN-04/05/06/12, FV-02/03, 3 Edge Cases). Fix cycle iteração 1 (6 commits: `9657e1e` `1ea38fd` `0232d46` `60cd903` `b20eff4` `46ce1a6`) resolveu os 6 Fix Plans; 2º Verifier achou só 1 gap residual (KN-06/Insert usava o mesmo handler do Space, nunca chamava `PanelCommands.toggleAndAdvance`). Fix iteração 2 (`2223763`) resolveu isso com `cursorID` state separado de `selection`. 3º Verifier (mesma sessão, iteração 2 do loop): **PASS**, 22/22 ACs re-derivados batem, 254/254 testes, sem gaps. `validate_state.py`: 0 erros. Relatório final: `.specs/features/convert-to-swift-swiftui/validation.md`.
- **Feature `classic-layout-parity`**: **DONE (`d7812c9`).** Layout clássico do mc original replicado: TopBar (Left/File/Command/Options/Right) + ButtonBar (F1-F10) + painéis com header/footer, sidebar de volumes removida. Aprovado via UAT interativo direto com o usuário (screenshot + "aprovado, pode commitar").
- **Pós-DONE, mesma sessão, tudo já mergeado em `main`** (merge commit `8a96752`, branch `convert-to-swift-swiftui` mantida por histórico):
  1. Remoção do projeto .NET/Avalonia legado (`88777c4`, 132 arquivos) — app é 100% Swift.
  2. Instalador (`packaging/build-macos.sh` + CI) quebrou por causa disso (chamava `dotnet publish`) — reescrito pra `swift build -c release` (`0ab4d15`), testado localmente (DMG gerado, bundle roda de verdade).
  3. Título da janela/app renomeado de "MCGui"/"MC GUI" pra "Midnight Commander" (`973d0a9`).
  4. **Bug reportado pelo usuário**: F5/F6 sempre oferecia o próprio painel como destino, não o outro (padrão dual-pane clássico) — corrigido com `PanelView.otherPanelPath` (`20dfccb`).
  5. **Bug reportado pelo usuário**: clique/duplo-clique do mouse nos painéis não funcionavam de forma confiável — 3 iterações até acertar: `.contentShape` + gesture (`86ab160`, duplo-clique ok mas simples ficou pior) → detecção por timing de `selection` (`a55e08f`, simples ok mas duplo parou de funcionar) → `NSTableView.doubleAction` nativo (`db682e6`, solução final correta — usa a mesma API que o AppKit usa pra distinguir clique simples/duplo, não compete com a seleção nativa). **Confirmado pelo usuário via DMG instalado: clique simples e duplo-clique OK.**
  6. Back/Forward (`fceb268`, `PathHistoryManager` plugado em `PanelViewModel`, FS-11/12/13 → Verified).
  7. Bookmarks (`8b2a83c` — **BookmarksView/BookmarkStore eram código morto de verdade**, nunca referenciados fora do próprio arquivo, não só "modelo local"; agora abre via TopBar Command > Bookmarks…, persiste em disco de verdade, BM-01..04 → Verified).
  8. `*` seleciona/desmarca tudo (KN-13 novo, `400b4bb` — `SelectionService.invert` já existia testado, só nunca tinha sido plugado, mesmo padrão do Bookmarks).
  9. Barra de progresso do copy/move mostrava bytes+ETA mas não "File N of M" — `OperationProgress.filesProcessed` adicionado (`7ae8f52`).
  10. Menu nativo do macOS: Copy/Move/Delete/View/Edit eram no-op (não alcançavam a seleção do painel) e o menu Go não tinha volumes — os dois resolvidos juntos (`61360bb`) movendo `pendingAction`/`PanelAction` de `MainWindow` (View, @State privado) pra `MainWindowViewModel` (`triggerActivePanel`, alcançável do `AppDelegate`); `AppDelegate` virou `@Observable` com lista de volumes própria (VL-01 → Verified).
  11. Syntax highlighting heurístico no viewer de texto (`0a64c7a` — comentários/strings/keywords/números, uma linha por vez, sem parser por linguagem; escopo escolhido pelo usuário. FV-02 → Verified).
  12. Cópia/move async de verdade (`0d606ed`, "faça a cópia async") — `ProgressDialog` era `.sheet` (modal, travava a janela toda); virou janela independente via `WindowManager.showProgress`, fecha sozinha quando termina. Guard novo: segundo F5/F6 no mesmo painel enquanto um já roda é no-op (antes o modal impedia isso implicitamente).
  13. F1 Help + F2 User Menu (`6addbde`, "faça o f1 e f2") — **features novas, zero código antes**, escopo bem reduzido em relação aos specs originais da era .NET (`help-system-f1`/`user-menu-f2`, 14+22 requirements com busca full-text, árvore de tópicos, editor drag-drop, 9 macros): F1 = janela estática com atalhos (singleton, `NSWindowDelegate` pra sobreviver ao botão vermelho fechar); F2 = `UserMenuStore`/`UserMenuRunner` (mirror do `BookmarkStore`) com itens shell customizáveis e macros `%f`/`%d`/`%D` só (das 9 originais). `PanelAction` ganhou `.userMenu`; ButtonBar 1/2 habilitados (só 9/PullDn segue desabilitado). **Confirmado pelo usuário via DMG instalado: F1 e F2 OK.**
- **Confirmado pelo usuário (DMG instalado)**: clique simples/duplo-clique (item 5), F1 Help, F2 User Menu.
- **Cópia/move async (item 12) - 4 bugs reais encontrados via teste real do usuário, todos corrigidos na mesma sessão**:
  14. Painel de destino não atualizava após copy/move - `performCopyMove` só recarregava o painel de origem (`viewModel.load()`), nunca o irmão. Novo `PanelView.onOperationCompleted`, `MainWindow` recarrega o painel oposto (`2087d2b`).
  15. Janela de progresso "não mostrava nada" em operações rápidas - abria e fechava no mesmo run loop antes do AppKit desenhar um frame. `WindowManager.showProgress` agora mantém a janela visível por no mínimo 0,5s (`2087d2b`).
  16. **Bug maior**: copiar uma pasta usava uma única chamada opaca `FileManager.copyItem` pro subtree inteiro - progresso só disparava (uma vez) no final, Cancel nunca era checado até a cópia inteira terminar. `FileSystemServiceImpl.copy`/`move` agora andam arquivo por arquivo dentro de diretórios (`copyDirectoryContents`, `expandedFiles`), com progresso e `Task.checkCancellation()` reais por arquivo. Corrigido de brinde: um `CancellationError` lançado de dentro do walk por arquivo estava caindo no catch genérico do loop por source e virando um "failed item" comum em vez de abortar o batch - agora relançado (`1c2f1c2`, 2 testes novos).
  17. Janela de progresso nunca fechava sozinha mesmo com a operação 100% concluída - `.onChange(of: isCompleted)` preso ao content da janela nunca reavaliava (nada mais no view tree mudava pra disparar o diffing do SwiftUI). Trocado por polling direto no MainActor (`a8dc1a9`).
  18. Paridade com o mc original: diálogo de F5/F6 ganhou botão "Background" (`Segundo plano`) - OK mostra progresso (padrão, como o mc original), Background roda sem abrir janela nenhuma (antes só existia o modo sempre-visível) (`aafdc85`). Os outros campos do diálogo clássico (Aprofundar no subdiretório, Vínculos simbólicos estáveis, padrão do shell) não foram adicionados - não têm comportamento correspondente implementado no motor de cópia.
  19. **Bug reportado pelo usuário**: pasta de 11GB deixava o diálogo "travado" logo após OK - `expandedFiles`/`copyDirectoryContents` faziam um `attributesOfItem` (stat extra) + resolução de symlink por arquivo, nunca usados de verdade (`copySingleFile` re-stata sozinho quando precisa). Trocado por `lightEntry` (só os 3 resource keys necessários), reduzindo ~pela metade as syscalls por arquivo no walk. Dialog agora mostra "Scanning…" durante esse pré-scan em vez de "File 0 of 0" parado (`0f09175`).
  20. Pedido do usuário: todas as janelas secundárias (viewer, editor, progresso, help, user menu) agora abrem centralizadas sobre a janela principal, não mais na posição em cascata padrão do AppKit (`0f09175`).
  21. **Bug reportado pelo usuário**: `*` deveria selecionar tudo, mas invertia a seleção (comportamento real do mc clássico) — desmarcava o que já estava marcado em vez de só adicionar. `PanelCommands.selectAll` substitui `invertSelection` (removido, não tinha mais uso). `*` agora sempre seleciona tudo, independente do estado anterior (`544e01a`).
  22. Pedido do usuário: teclado físico sem tecla Insert confiável (comum em Mac) — `+` vira tecla secundária pro Insert (toggle da linha atual + avança), `-` limpa toda a seleção (oposto natural do `*`/select-all) (`544e01a`).
- **Next step**: pedir confirmação final da cópia/move (progresso real, refresh, cancel, background) no DMG reconstruído. Gaps grandes que sobraram, não iniciados: paginação de pastas com 10k+ arquivos (decisão explícita do usuário de deixar pra depois) e as features do mc original ainda sem nenhum código (Find File, Tree, Diff Viewer, Chmod/Chown/Chattr, Subshell, VFS/FTP, fila de operações em background, tela de configurações, Windows/Linux).
- **Blockers**: none.
- **Uncommitted files**: `.specs/LESSONS.md`/`.specs/lessons.json` (lições L-010..L-015 do ciclo de verificação) e `.specs/features/convert-to-swift-swiftui/validation.md` (relatório PASS final, untracked) — pendentes desde o merge, nunca commitados nessa branch.
- **Branch**: `main` — pushed até `544e01a`. `convert-to-swift-swiftui` também existe (histórico, já mergeada).

---

### Handoff history (features anteriores nesta branch/repo, para contexto)

- **Feature `macos-native-chrome`**: DONE, pushed (`699daca`).
- **Bug fix `F1/F9/F10`**: corrigido em `56c4071` (local, não pushed) — F9/F10 agora funcionam via Click; F1 desabilitado (sem Help viewer). F2 "Menu" tem o mesmo problema mas não foi tocado (fora de escopo).
- **Feature `copy-move-mc-options`**: DONE — 10 tasks, Verifier PASS, 236 testes.
- **Feature `macos-installer`**: DONE — 4 tasks, `build-macos.sh` + GitHub Actions `build-macos.yml`, DMG em `artifacts/`.
- **Feature `viewer-f3`**: PARCIAL (6/7 tasks) — T5 (Hex mode) ainda pendente na versão C#/Avalonia; **superseded** pela reescrita Swift (a feature `convert-to-swift-swiftui` cobre hex mode nativamente em FV-04/T36).

(End of file - total 18 lines)