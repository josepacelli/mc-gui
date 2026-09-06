# macOS Native Chrome Specification

## Problem Statement

MC GUI hoje abre com chrome padrão do Avalonia: barra de título do SO separada, menu Avalonia (`Menu`) dentro da janela, lista de arquivos em `ListBox` sem estilo nativo, e barra de botões F1-F10 com aparência genérica. O usuário quer que, no macOS, a janela tenha a aparência de um app nativo (referência: Monitor de Atividade) — título estendido com semáforo inline, menu no menu bar do sistema, e componentes com acabamento nativo — sem alterar nenhuma funcionalidade existente.

## Goals

- [ ] No macOS, a janela usa barra de título estendida com semáforo (círculos vermelho/amarelo/verde) inline, no estilo de apps nativos.
- [ ] No macOS, os mesmos comandos do menu hoje disponíveis na `Menu` da janela também aparecem no menu bar nativo do sistema.
- [ ] No macOS, lista de arquivos dos painéis e barra de botões F1-F10 recebem acabamento visual nativo (linhas alternadas/hover, botões estilo toolbar), sem mudar nenhum comando ou binding existente.
- [ ] Windows e Linux mantêm o chrome atual, inalterado.

## Out of Scope

Explicitamente excluído. Documentado para prevenir scope creep.

| Feature | Reason |
| --- | --- |
| Controle segmentado tipo "CPU/Memória/Energia..." | Decisão do usuário: sem equivalente funcional no mc-gui; a referência serve só de estilo de chrome, não de layout de conteúdo |
| Cabeçalho de duas linhas (título + subtítulo, ex. "Monitor de Atividade" / "Todos os Processos") | Não pedido; app já tem título de janela próprio ("Midnight Commander GUI") — não precisa de identidade duplicada no toolbar |
| Campo de busca (search field) no canto superior direito | Sem funcionalidade de busca correspondente hoje no mc-gui; fora de escopo desta feature |
| Rodapé com gráfico ("Pressão de Memória") | Sem métrica equivalente no mc-gui; fora de escopo |
| Restyle para Windows/Linux | Decisão do usuário: chrome nativo é conceito específico de macOS; Windows/Linux ficam como estão até terem sua própria feature |
| Assinatura/notarização, ícone refinado | Já registrados como backlog separado em `.specs/STATE.md` |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Onde vive a checagem de plataforma | `OperatingSystem.IsMacOS()` inline em `McGui.App` (sem novo projeto `Infrastructure`) | Avalonia já abstrai `ExtendClientAreaToDecorationsHint`/`NativeMenu` por SO; não há chamada de API de SO real que exija a camada de `Infrastructure.<Plataforma>` do AD-001 — motor de decisão continua em `McGui.App`, único ponto de UI | n |
| Altura/posição exata do semáforo | Usar `ExtendClientAreaToDecorationsHint="True"` + `WindowDecorations="Full"` (mantém botões nativos do SO) + `ExtendClientAreaTitleBarHeightHint` padrão, sem pixel-matching manual da screenshot | Confirmado via docs Avalonia: `WindowDecorations="Full"` mantém minimize/maximize/close nativos junto de um título estendido; `ExtendClientAreaChromeHints` foi removido no Avalonia 12, então não é usado | n |
| Menu nativo é cópia ou fonte única | `NativeMenu` é populado a partir da mesma lista de comandos/`MenuItem` já bindada na `Menu` in-window (mesmo `Command`/`CommandParameter`), mantendo os dois em paralelo | Usuário pediu explicitamente "criar uma cópia... e restyle visual" — a `Menu` in-window continua existindo (F2/PullDownMenu depende dela) e a `NativeMenu` é uma segunda árvore de itens ligada aos mesmos comandos | y |
| Itens desabilitados (`IsEnabled="False"`) do menu original | Espelhados como desabilitados também no `NativeMenu` | Consistência - nenhum item ganha funcionalidade nova nesta feature | n |
| Estilo de linha na lista de arquivos | Sem zebra-striping (Avalonia não tem `AlternationCount` confirmado); apenas refinar brushes de hover/seleção do `ListBoxItem` via `Style Selector`, mesmo padrão já usado em `PanelView.axaml` (`Border.panelRoot`) | Solução mais simples: reutiliza o mecanismo de `Style Selector` que já existe no projeto, sem depender de API não verificada nem introduzir lógica de alternância | n |
| Tamanho mínimo de janela | Sem mudança - não há `MinWidth`/`MinHeight` definido hoje, e esta feature não introduz um | Fora do escopo pedido pelo usuário; extensão de client area não exige mínimo novo | n |
| Reaplicação do chrome ao trocar tema em runtime | Reaproveita o hook já existente `OnViewModelPropertyChanged`/`ApplyTheme` em `MainWindow.axaml.cs` para reprocessar os brushes nativos junto da troca de tema | Já existe o mecanismo de reagir a `CurrentTheme`; basta os novos brushes serem `DynamicResource` nos temas Light/Dark de `Themes.axaml` | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Barra de título estendida com semáforo inline (macOS) ⭐ MVP

**User Story**: Como usuário macOS, quero que a janela do MC GUI tenha o semáforo inline numa barra de título estendida, para que o app pareça nativo do sistema.

**Why P1**: É a mudança visual mais visível da referência e não depende de nenhuma outra parte da feature.

**Acceptance Criteria**:

1. WHEN o app inicia rodando em macOS THEN a `MainWindow` SHALL habilitar `ExtendClientAreaToDecorationsHint=true` com o semáforo (close/minimize/maximize) renderizado inline na área estendida.
2. WHILE o app roda em Windows ou Linux THEN a `MainWindow` SHALL manter `ExtendClientAreaToDecorationsHint` desabilitado (chrome padrão do SO, inalterado).
3. WHEN o usuário redimensiona ou maximiza a janela no macOS THEN os painéis, menu in-window e barra F1-F10 SHALL continuar visíveis e funcionais abaixo da área estendida (sem sobreposição de conteúdo pelo semáforo).
4. The title da janela SHALL continuar "Midnight Commander GUI" (sem mudança de texto).

**Independent Test**: Rodar o app em macOS e ver o semáforo inline no topo da janela; rodar (ou simular via flag de teste de plataforma) o mesmo código em Windows/Linux e confirmar chrome padrão inalterado.

---

### P2: Menu nativo do macOS espelhando o menu in-window

**User Story**: Como usuário macOS, quero acessar File/Command/Options/etc. pelo menu bar do sistema, para que o app siga a convenção nativa de menus do macOS.

**Why P2**: Depende do P1 estar em vigor (mesma checagem de plataforma) mas é funcionalmente independente - pode ser demonstrado sozinho apontando o mouse no menu bar do sistema.

**Acceptance Criteria**:

1. WHEN o app inicia rodando em macOS THEN o menu bar do sistema SHALL exibir os mesmos headers de topo hoje presentes na `Menu` in-window (`_Left`, `_File`, `_Command`, `_Options`, `_Right`) via `NativeMenu`.
2. WHEN um item do `NativeMenu` com `Command` habilitado é clicado THEN o mesmo `Command`/`CommandParameter` já bindado no item equivalente da `Menu` in-window SHALL ser executado (nenhum comando novo, nenhuma duplicata de lógica).
3. IF um item da `Menu` in-window está com `IsEnabled="False"` THEN o item espelhado no `NativeMenu` SHALL também estar desabilitado.
4. WHILE o app roda em Windows ou Linux THEN nenhum `NativeMenu` SHALL ser exibido no menu bar do sistema (comportamento padrão do Avalonia nessas plataformas, sem regressão da `Menu` in-window que já funciona hoje).
5. The `Menu` in-window (incluindo o atalho F2 / `PullDownMenu` que abre `MainMenu.Items[0]`) SHALL continuar funcionando sem alteração de comportamento, apenas com restyle visual (ver P3).

**Independent Test**: No macOS, clicar em "Command" no menu bar do sistema e executar "Rescan" - painel ativo recarrega, igual ao mesmo comando disparado pela `Menu` in-window.

---

### P3: Acabamento visual nativo em lista de arquivos e barra F1-F10 (macOS)

**User Story**: Como usuário macOS, quero que a lista de arquivos e os botões de função tenham acabamento visual nativo (linhas alternadas/hover, botões estilo toolbar), para que o app pareça consistente com o resto do sistema.

**Why P3**: É puramente estético e não bloqueia P1/P2; pode ser validado visualmente de forma independente.

**Acceptance Criteria**:

1. WHILE o app roda em macOS com tema Dark THEN o `ListBoxItem` da lista de arquivos de cada painel SHALL usar brushes de hover/seleção nativos escuros definidos em `Themes.axaml` (sem zebra-striping).
2. WHILE o app roda em macOS com tema Light THEN o `ListBoxItem` da lista de arquivos de cada painel SHALL usar os brushes de hover/seleção nativos claros equivalentes.
3. WHEN o usuário troca o tema (System/Light/Dark) em runtime no macOS THEN os brushes de alternância e dos botões F1-F10 SHALL ser reaplicados imediatamente, sem exigir reiniciar o app.
4. The barra de botões F1-F10 SHALL manter os mesmos `Command`/`CommandParameter`/estados `IsEnabled` de hoje, apenas com estilo visual atualizado (aparência de toolbar nativo: flat, hover, fonte do sistema).
5. WHILE o app roda em Windows ou Linux THEN lista de arquivos e barra F1-F10 SHALL manter a aparência atual (sem os brushes/estilos novos desta feature).

**Independent Test**: Alternar entre tema Light e Dark no macOS e ver a lista de arquivos e a barra F1-F10 mudarem de acabamento instantaneamente, sem nenhum comando parar de funcionar.

---

## Edge Cases

- IF o app roda em uma versão de macOS/Avalonia onde `ExtendClientAreaToDecorationsHint` não é suportado THEN a `MainWindow` SHALL cair de volta ao chrome padrão (mesmo comportamento de Windows/Linux), sem crash.
- IF o `NativeMenu` falhar ao ser atribuído (ex.: ambiente sem menu bar, como CI headless) THEN o app SHALL continuar funcional via `Menu` in-window (sem exceção não tratada).
- WHEN a janela está em tela cheia no macOS THEN o semáforo/área estendida SHALL seguir o comportamento padrão do Avalonia para fullscreen (sem lógica customizada adicional nesta feature).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| MACUI-01 | P1: Barra de título estendida | T1, T9 | Implementing |
| MACUI-02 | P1: Barra de título estendida | T1 | Implementing |
| MACUI-03 | P1: Barra de título estendida | T1, T9 | Implementing |
| MACUI-04 | P1: Barra de título estendida | T1, T7 | Implementing |
| MACUI-05 | P2: Menu nativo | T2 | Implementing |
| MACUI-06 | P2: Menu nativo | T2, T8 | Implementing |
| MACUI-07 | P2: Menu nativo | T2 | Implementing |
| MACUI-08 | P2: Menu nativo | T2 | Implementing |
| MACUI-09 | P2: Menu nativo | T2 | Implementing |
| MACUI-10 | P3: Acabamento nativo | T3, T5, T6 | Implementing |
| MACUI-11 | P3: Acabamento nativo | T3, T5 | Implementing |
| MACUI-12 | P3: Acabamento nativo | T4, T6 | Implementing |
| MACUI-13 | P3: Acabamento nativo | T4, T5 | Implementing |
| MACUI-14 | P3: Acabamento nativo | T4, T6 | Implementing |

**ID format:** `MACUI-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 14 total, 14 mapped to tasks, 0 unmapped ✅

---

## Success Criteria

- [ ] No macOS, janela abre com semáforo inline na área de título estendida (P1).
- [ ] No macOS, menu bar do sistema mostra os mesmos headers/itens/estados da `Menu` in-window e executa os mesmos comandos (P2).
- [ ] No macOS, lista de arquivos e barra F1-F10 mudam de acabamento junto com a troca de tema, sem quebrar nenhum comando existente (P3).
- [ ] Em Windows/Linux, nenhuma mudança de comportamento ou aparência é observável (regressão zero).
- [ ] Suite de testes existente (180 testes) continua passando; novos testes cobrem a checagem de plataforma (macOS vs. não-macOS) para chrome/menu/estilos.
