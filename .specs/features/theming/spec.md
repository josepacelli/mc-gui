# Theming Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O `mc-gui` hoje usa `FluentTheme` com `RequestedThemeVariant="Default"` (segue o sistema), mas todas as cores específicas do app estão **hardcoded** nos arquivos `.axaml` (borda de painel `Gray`/`DodgerBlue`, overlay de loading `#AA000000` + texto `White`, overlay de diretório inacessível `#DD400000` + texto `White`, erro `Red`, aviso de exclusão permanente `OrangeRed`). Isso produz contraste inconsistente entre tema claro e escuro, impede ajuste fino por variante e dificulta evolução visual.

Esta feature cria uma paleta semântica central via `ResourceDictionary` do Avalonia com variantes `Light`/`Dark` (mecanismo `ThemeDictionaries` + `RequestedThemeVariant`, confirmado na doc oficial da versão 12), substitui todo cor hardcoded por referências dinâmicas e adiciona controle de tema: **seguir o sistema por padrão**, com override manual **Light/Dark/System** via `MenuBar` sempre visível e via teclado (**F12** cicla). Sem identidade visual específica do MC nesta feature — apenas tema consistente e centralizado.

## Goals

- [ ] Todas as cores específicas do app centralizadas em um `ResourceDictionary` com variantes `Light` e `Dark`; nenhuma cor hardcoded restante nos views.
- [ ] Aplicação segue o tema do sistema na inicialização (sem persistência de escolha manual entre execuções).
- [ ] Usuário alterna `Light`/`Dark`/`System` via `MenuBar` e via `F12` (ciclo System→Light→Dark), aplicação reage imediatamente em janela principal e diálogos.
- [ ] Contraste legível em ambos os temas (validação visual em UAT interativo).

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Skins/temas customizáveis pelo usuário (carregar paleta externa) | Feature futura própria; requer persistência + formato |
| Identidade visual inspirada no MC clássico (retro/terminal) | Decisão do usuário: tema consistente moderno; estética MC fica fora |
| Persistência da escolha manual de tema entre execuções | Decisão do usuário: sessão apenas; persistência é feature futura |
| Persistir posição/tamanho da MenuBar ou preferências de janela | Fora do escopo de tema |
| Tema separado por diálogo individual | Escopo: uma paleta global aplicada a janela principal + todos os diálogos |
| Suporte a tema por painel (painel esquerdo claro, direito escuro) | Sem necessidade; `ThemeVariantScope` por subárvore não é requisito |

---

## Assumptions & Open Questions

Toda ambiguidade foi resolvida ou registrada aqui - nada fica silenciosamente indefinido.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Mecanismo de tema | `ResourceDictionary` com `ThemeDictionaries` (chaves `Light`, `Dark`, fallback `Default`) + referências `{DynamicResource ...}` em todos os views; controles padrão (Button/TextBox/ListBox etc.) permanecem com `FluentTheme` | Documentado em docs.avaloniaui.net/docs/styling/theme-variants; `StaticResource` não resolve dentro de `ThemeDictionaries` — só `DynamicResource` | y |
| Seguir sistema | App inicia com `RequestedThemeVariant="Default"`; mudança de tema do SO em runtime reflete no app enquanto em modo System | Mecanismo nativo Avalonia 12; nada extra a implementar além de não fixar variante | y |
| Escopo da paleta | Apenas cores específicas do app hoje hardcoded (borda painel, overlays, erro, aviso) viram tokens semânticos; o resto vem do `FluentTheme` | "Só tema consistente": centralizar o que é nosso, não redesenhar controles Fluent | y |
| Override manual | Menu `Theme` com itens `Light`/`Dark`/`System` na `MenuBar` do topo + `F12` cicla na ordem System→Light→Dark→System | Decisões do usuário capturadas na fase de discussão | y |
| Persistência | Escolha manual vale só na sessão atual; fechar e reabrir volta a `System` | Decisão do usuário (sessão apenas) | y |
| Valores das cores | Tabela de tokens proposta na seção "Paleta semântica" com valores por variante; verificação de contraste em UAT | Necessário valores concretos para contraste e UAT | n |
| Efeito visual aplicado a diálogos abertos | Diálogos herdam a variante do app automaticamente (não fixam `RequestedThemeVariant`) | `Window`/`TopLevel` herdam a variante do `Application` a menos que override explícito | y |
| Verificação automatizada | Lógica do toggle (ciclo, estado, mapeamento) testada em xunit puro; presença de cores hardcoded e resolução de recursos verificadas por varredura estrutural dos `.axaml` + build-gate; resultado visual final validado por UAT interativo | Não há `Avalonia.Headless` no projeto hoje; decisão do usuário "lógica em testes + UAT visual" | y |
| F12 como tecla | `F12` livre no `KeyGestureMap`; nenhum conflito com F-keys MC nem `Ctrl+R`/`Ctrl+H` | Verificado em `src/McGui.App/Input/KeyGestureMap.cs` | y |
| Semântica de `System` vs `Default` | `System` no menu = `RequestedThemeVariant="Default"` (equivalente na UI ao termo System) | Vocabulário de usuário | y |

**Open questions:** none - todas resolvidas ou registradas acima (valores de cor da paleta estão como proposta marcada Confirmed: n para confirmação nesta revisão).

### Paleta semântica (valores propostos — Confirmed: n)

Tokens semânticos definidos nas variantes `Light` e `Dark`:

| Token | Uso atual | Light | Dark |
| --- | --- | --- | --- |
| `PanelBorderBrush` | Borda painel inativo (`Gray`) | `#B0B0B0` | `#4D4D4D` |
| `PanelBorderActiveBrush` | Borda painel ativo (`DodgerBlue`) | `#0066CC` | `#4CB3FF` |
| `OverlayLoadingBackgroundBrush` | Overlay loading (`#AA000000`) | `#CCF5F5F5` | `#CC000000` |
| `OverlayLoadingForegroundBrush` | Texto do loading (`White`) | `#333333` | `#FFFFFF` |
| `OverlayErrorBackgroundBrush` | Overlay dir inacessível (`#DD400000`) | `#E6FCE8E8` | `#CC5C2B2B` |
| `OverlayErrorForegroundBrush` | Texto do erro de dir (`White`) | `#B00020` | `#FFFFFF` |
| `TextErrorBrush` | Mensagem de erro de diálogo (`Red`) | `#B00020` | `#FF8A80` |
| `TextWarningBrush` | Aviso exclusão permanente (`OrangeRed`) | `#C2410C` | `#FFB74D` |

---

## User Stories

### P1: Paleta central de tema com variantes Light/Dark ⭐ MVP

**User Story**: As a usuário, I want as cores do mc-gui definidas em uma paleta central que se adapta ao tema claro/escuro, so that a interface mantém contraste e consistência sem cores fixas espalhadas.

**Why P1**: Sem paleta central não existe tema — é o alicerce de toda a feature.

**Acceptance Criteria** (cada linha é um padrão EARS):

1. The app SHALL define every semantic token in the "Paleta semântica" table with a distinct value for the `Light` variant and a distinct value for the `Dark` variant. <!-- ubiquitous -->
2. The app SHALL define each semantic token so that it resolves through `DynamicResource` from any view, for both the `Light` and `Dark` variants. <!-- ubiquitous -->
3. WHEN the requested theme variant is `Light` THEN every view that references a semantic token SHALL render that token's `Light` value. <!-- event-driven -->
4. WHEN the requested theme variant is `Dark` THEN every view that references a semantic token SHALL render that token's `Dark` value. <!-- event-driven -->

**Independent Test**: Executar o app em modo claro e em modo escuro e conferir, nos dois painéis e nos diálogos, que as cores correspondem à tabela da variante ativa.

---

### P1: Views sem cores hardcoded ⭐ MVP

**User Story**: As a usuário, I want que nenhum view defina cor fixa fora da paleta, so that tema claro/escuro é consistente e a evolução visual é centralizada.

**Why P1**: Cores hardcoded quebram o contrato da paleta e do contraste.

**Acceptance Criteria**:

1. IF a view `.axaml` under `src/McGui.App/Views` or `src/McGui.App/MainWindow.axaml` sets `Background`, `Foreground`, or `BorderBrush` THEN the value SHALL be a `{DynamicResource ...}` reference or a transparent/non-color value (`Transparent`, `{x:Null}`). <!-- unwanted-behavior -->
2. IF a view uses a color literal (named color such as `Red`, or hex such as `#RRGGBB`) for a visual property THEN the structural scan test SHALL fail. <!-- unwanted-behavior -->
3. The `Styles` in `PanelView.axaml` (borda ativa/inativa) SHALL reference `PanelBorderActiveBrush` and `PanelBorderBrush` instead of literal colors. <!-- ubiquitous -->

**Independent Test**: Varredura estrutural dos `.axaml` não encontra cor literal (hex ou nome) em propriedade visual; build passa.

---

### P1: Seguir o sistema por padrão ⭐ MVP

**User Story**: As a usuário, I want que o app abra seguindo o tema do sistema, so that não há surpresa de tema na primeira execução.

**Why P1**: É o comportamento default acordado; base de qualquer override manual.

**Acceptance Criteria**:

1. WHEN the app starts THEN the requested theme variant SHALL be `Default` (follow the system). <!-- event-driven -->
2. WHILE no manual override has been made in the session AND the system theme changes THEN the app SHALL reflect the new system theme. <!-- state-driven -->
3. WHEN the app restarts THEN any manual override from a previous session SHALL NOT be restored. <!-- event-driven -->

**Independent Test**: Rodar o app com o SO em claro e em escuro (sem tocar no menu) e conferir que a interface acompanha o sistema; fechar, mudar tema no menu, reabrir e conferir que voltou ao sistema.

---

### P1: Override manual via MenuBar ⭐ MVP

**User Story**: As a usuário, I want escolher explicitamente Light/Dark/System em um menu no topo, so that posso forçar o tema independente do sistema.

**Why P1**: Override manual é o controle central que o usuário pediu, junto com seguir sistema.

**Acceptance Criteria**:

1. The app SHALL show a `MenuBar` with a `Theme` menu at the top of the main window. <!-- ubiquitous -->
2. The `Theme` menu SHALL contain exactly three items: `Light`, `Dark`, and `System`. <!-- ubiquitous -->
3. WHEN the user selects `Light` in the `Theme` menu THEN the requested theme variant SHALL become `Light` immediately. <!-- event-driven -->
4. WHEN the user selects `Dark` in the `Theme` menu THEN the requested theme variant SHALL become `Dark` immediately. <!-- event-driven -->
5. WHEN the user selects `System` in the `Theme` menu THEN the requested theme variant SHALL become `Default` (follow the system) immediately. <!-- event-driven -->
6. WHILE the current variant is `Light` THEN the `Light` menu item SHALL be checked (and the others unchecked). <!-- state-driven -->
7. WHILE the current variant is `Dark` THEN the `Dark` menu item SHALL be checked (and the others unchecked). <!-- state-driven -->
8. WHILE the current variant is `Default` THEN the `System` menu item SHALL be checked (and the others unchecked). <!-- state-driven -->

**Independent Test**: Executar o app, escolher cada item do menu `Theme` e conferir mudança imediata de claro/escuro na janela principal e nos diálogos, com o item ativo marcado.

---

### P1: Ciclo rápido por teclado (F12) ⭐ MVP

**User Story**: As a usuário (teclado-centrico como MC), I want alternar tema sem o mouse, so that o fluxo de teclado permanece completo.

**Why P1**: mc-gui é teclado-centrico; controle por mouse sozinho não basta.

**Acceptance Criteria**:

1. WHEN the user presses `F12` THEN the theme SHALL cycle to the next variant in the order System→Light→Dark→System. <!-- event-driven -->
2. WHEN the user presses `F12` while the current variant is `System` THEN the requested theme variant SHALL become `Light`. <!-- event-driven -->
3. WHEN the user presses `F12` while the current variant is `Light` THEN the requested theme variant SHALL become `Dark`. <!-- event-driven -->
4. WHEN the user presses `F12` while the current variant is `Dark` THEN the requested theme variant SHALL become `Default` (System). <!-- event-driven -->
5. WHILE the variant changes via `F12` THEN the `Theme` menu check state SHALL update to match. <!-- state-driven -->

**Independent Test**: Executar o app e pressionar `F12` repetidamente; conferir a alternância System→Light→Dark→System com o item de menu acompanhando.

---

## Edge Cases

- IF the user changes the system theme while a manual `Light` or `Dark` override is active THEN the app SHALL keep the manual override (not follow the system). <!-- unwanted-behavior -->
- IF a semantic token referenced by a view is missing from both theme dictionaries THEN the app SHALL still build and run (resource resolution happens at render; missing key renders default), and the structural test SHALL flag the missing key. <!-- unwanted-behavior -->
- WHEN the user presses `F12` repeatedly SHALL the cycle never get stuck and always return to `System` after three presses. <!-- complex -->
- IF the app is in `Light` or `Dark` override AND the user reopens a dialog THEN the dialog SHALL inherit the current override variant. <!-- unwanted-behavior -->

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| THM-01 | P1: Paleta central | Design | Verified |
| THM-02 | P1: Paleta central | Design | Verified |
| THM-03 | P1: Paleta central | Design | Verified |
| THM-04 | P1: Paleta central | Design | Verified |
| THM-05 | P1: Views sem cores hardcoded | Design | Verified |
| THM-06 | P1: Views sem cores hardcoded | Design | Verified |
| THM-07 | P1: Views sem cores hardcoded | Design | Verified |
| THM-08 | P1: Seguir o sistema por padrão | Design | Verified |
| THM-09 | P1: Seguir o sistema por padrão | Design | Verified |
| THM-10 | P1: Seguir o sistema por padrão | Design | Verified |
| THM-11 | P1: Override via MenuBar | Design | Verified |
| THM-12 | P1: Override via MenuBar | Design | Verified |
| THM-13 | P1: Override via MenuBar | Design | Verified |
| THM-14 | P1: Override via MenuBar | Design | Verified |
| THM-15 | P1: Override via MenuBar | Design | Verified |
| THM-16 | P1: Override via MenuBar | Design | Verified |
| THM-17 | P1: Override via MenuBar | Design | Verified |
| THM-18 | P1: Override via MenuBar | Design | Verified |
| THM-19 | P1: Ciclo rápido (F12) | Design | Verified |
| THM-20 | P1: Ciclo rápido (F12) | Design | Verified |
| THM-21 | P1: Ciclo rápido (F12) | Design | Verified |
| THM-22 | P1: Ciclo rápido (F12) | Design | Verified |
| THM-23 | P1: Ciclo rápido (F12) | Design | Verified |

**ID format:** `THM-N`
**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 23 total, 23 mapped to tasks, 0 unmapped

---

## Success Criteria

- [ ] `rg` por cores hardcoded (hex `#` e nomes de cor) em `src/McGui.App/**/*.axaml` não retorna ocorrência em propriedade visual de views (exceto no arquivo da paleta).
- [ ] Execução do app em modo claro e escuro (SO) e nos três estados do menu não revela texto ilegível ou contraste quebrado (UAT).
- [ ] `F12` e menu `Theme` produzem o mesmo estado e a interface reage imediatamente.
- [ ] Todos os 108+ testes existentes continuam passando.
