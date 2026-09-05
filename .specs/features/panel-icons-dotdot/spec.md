# Panel Icons + ".." Entry Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

Os painéis do mc-gui listam apenas texto (nome + tamanho). Diferente do Midnight Commander original, não há indicador visual de tipo (arquivo vs diretório) e não há entrada `..` no topo do painel: hoje o usuário volta ao diretório pai com Backspace ou pelo item pai quando existe como entrada real. Isso reduz a paridade visual/navegacional com o MC.

Esta feature (fatia A) dá aos painéis: (1) ícone vetorial de pasta ou de arquivo à esquerda de cada linha (`ícone nome`), (2) entrada `..` como primeira linha do painel (exceto no diretório raiz) que navega para o pai, seguindo a semântica do MC original (`src/filemanager/panel.c`, `src/filemanager/dir.c`): `..` sempre no topo, não marcável, ativado volta ao pai pousando o cursor sobre a pasta de origem, (3) **tamanho dos arquivos formatado em kB/MB/GB/TB** (base 1024; diretórios e `..` exibem coluna de tamanho vazia).

## Goals

- [ ] Cada linha do painel mostra um ícone vetorial (pasta ou arquivo) antes do nome; diretórios mantêm o `/` sufixo.
- [ ] Entrada `..` presente como primeira linha (exceto raiz); Enter/duplo-clique navega ao pai e o cursor pousa sobre a pasta de origem.
- [ ] `..` nunca é marcável e não entra em operações de arquivo; a navegação por teclado (Up/Down/Enter/Backspace) permanece coerente com a presença do `..`.
- [ ] Tamanho dos arquivos exibido formatado em kB/MB/GB/TB (base 1024); diretórios e `..` deixam a coluna de tamanho vazia.
- [ ] Contraste e tema (claro/escuro) dos ícones seguem a paleta semântica existente.

## Out of Scope

Explicitamente excluído desta feature (fatia B separada).

| Feature | Motivo |
| --- | --- |
| Menubar F9 replicando o MC original (Left/File/Command/Options/Right) | Fatia B, spec própria |
| Ícones por tipo de arquivo (extensão) | Decisão: apenas pasta vs arquivo genérico |
| Ícones customizáveis / skins | Fora do escopo de tema consistente |
| Coluna de tamanho com formatação humana (K/M/G) | Não pedido; mantém bytes crus |
| Permissões/owner/datas nas linhas | Não pedido |
| Drag & drop entre painéis | Feature futura |
| Ordenação configurável (nome/tamanho/data) | mc-gui não tem sort hoje; `..` fica fixo no topo independente de qualquer ordem futura |
| Seleção com o mouse em modo "só leitura" de painel (Info/Tree etc.) | Painéis são listing; modos extras são fatia B/outras features |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Ícone | `PathIcon`/`StreamGeometry` vetorial embutido no XAML (sem asset externo), 2 formas: pasta e arquivo | Decisão do usuário "PathIcon vetorial embutido" | y |
| Granularidade | Pasta vs arquivo genérico; symlink apenas herda o ícone do alvo (pasta se aponta p/ dir, senão arquivo) | Decisão "pasta + arquivo"; sem badge de symlink por ora | y |
| Entrada `..` | Sempre primeira linha, exceto no diretório raiz do FS | Padrão MC (`dir.c` só omite `..` na raiz) | y |
| `..` não marcável | Espaço/Insert sobre `..` não marca; seleção por padrão (`+`), inversão (`*`) e desmarcar (`-`) ignoram `..` | `panel.c:4811` `file_mark` retorna cedo p/ DOTDOT; marcação não deve incluir `..` | y |
| Cursor ao subir | Ao ativar `..`, o cursor no pai pousa sobre a entrada com o nome do diretório de onde se veio | Padrão MC | y |
| Cursor ao entrar | Ao navegar p/ dentro de um diretório, cursor começa no 1º item real (não em `..`) | Decisão do usuário | y |
| Cursor na raiz | Raiz não tem `..`; cursor no primeiro item real | Consistente | y |
| Posição de `..` vs sort | `..` sempre no topo, fora da ordem; hoje não há sort configurável | Decisão | y |
| Navegação via `..` | `ActivateCursorEntryAsync` em `..` faz o mesmo que `NavigateToParentAsync` (Backspace) | Backspace e `..` convergem no mesmo comportamento de subir | y |
| Interface do painel | A entrada `..` é injetada na lista de `PanelState.Entries` pela camada App (PanelViewModel) — `IFileSystemService.ListDirectory`/Infra seguem retornando só entradas reais. `SelectionService` (Core) ganha guarda por nome `..` (mesma semântica de `DIR_IS_DOTDOT` no MC) para nunca marcá-lo | O painel navega sobre a lista exibida; deixar `..` fora do serviço mantém Infra pura | y |
| Testes | Lógica (construção da lista com `..`, cursor na origem, não-marcável, exclusão de `..` das operações) testável em xunit; camada visual (ícone renderizado, PathIcon) por build-gate + UAT | Padrão já usado (lógica em testes + UAT visual) | y |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Ícone de pasta/arquivo em cada linha ⭐ MVP

**User Story**: As a usuário, I want ver um ícone que distingue pasta de arquivo à esquerda de cada linha, so that a varredura visual é imediata como no MC.

**Why P1**: É o pedido central visual da fatia.

**Acceptance Criteria** (cada linha é um padrão EARS):

1. The panel SHALL render, before the entry name, an icon that shows a folder glyph for every directory entry and a file glyph for every non-directory entry. <!-- ubiquitous -->
2. WHEN the requested theme variant is `Light` or `Dark` THEN the icon colors SHALL resolve through `DynamicResource` so they are legible in both variants. <!-- event-driven -->
3. The folder icon SHALL also be shown for the `..` entry. <!-- ubiquitous -->
4. IF an entry is a symlink pointing to a directory THEN the panel SHALL show the folder icon; otherwise the file icon. <!-- unwanted-behavior -->

**Independent Test**: Executar o app em tema claro e escuro; painel mostra pastas com ícone de pasta e arquivos com ícone de arquivo; `..` exibe pasta.

---

### P1: Entrada `..` no topo do painel ⭐ MVP

**User Story**: As a usuário, I want uma linha `..` no topo (exceto na raiz) que sobe ao diretório pai, so that posso navegar para cima com o mouse/teclado como no MC.

**Why P1**: Navegação estrutural pedida.

**Acceptance Criteria**:

1. WHEN the current directory is not the filesystem root THEN the first row of the panel SHALL be a `..` entry. <!-- event-driven -->
2. WHEN the current directory is the filesystem root THEN the panel SHALL NOT show a `..` entry. <!-- event-driven -->
3. WHEN the user activates the `..` entry (Enter or double-click) THEN the panel SHALL navigate to the parent directory. <!-- event-driven -->
4. WHEN the panel navigates up via `..` THEN the cursor SHALL land on the entry whose name equals the directory that was left. <!-- event-driven -->
5. WHEN the user navigates into a directory (not via `..`) THEN the cursor SHALL start on the first real entry, not on `..`. <!-- event-driven -->

**Independent Test**: Navegar para um subdiretório (cursor no 1º item), voltar com `..` (cursor pousa na pasta de origem), chegar à raiz (sem `..`).

---

### P1: `..` não marcável e excluído de operações ⭐ MVP

**User Story**: As a usuário, I want que `..` nunca seja selecionado/marcado nem entre em copiar/mover/apagar, so that operações não tentam tocar o diretório pai.

**Why P1**: Integridade das operações de arquivo (não copiar `..`, não somar `..` em bytes).

**Acceptance Criteria**:

1. WHEN the user toggles a mark on the `..` row THEN the `..` entry SHALL NOT become marked. <!-- event-driven -->
2. WHEN the user marks by pattern, inverts marks, or unmarks by pattern THEN the `..` entry SHALL never end up marked. <!-- event-driven -->
3. WHEN the user requests copy/move/delete with no real entry marked THEN the operation SHALL behave as if no source was selected (the `..` row alone is never a source). <!-- event-driven -->
4. The marked-count and marked-size totals SHALL never include the `..` entry. <!-- ubiquitous -->

**Independent Test**: Marcar tudo (`*`) num diretório não-raiz: `MarkedCount` só conta entradas reais; solicitar cópia com apenas `..` "selecionado" não abre diálogo.

---

### P1: Tamanho formatado (kB/MB/GB/TB) ⭐ MVP

**User Story**: As a usuário, I want ver o tamanho dos arquivos em unidades legíveis (kB/MB/GB/TB), so that não preciso decodificar bytes crus.

**Why P1**: Coluna de tamanho legível é parte da paridade visual com o MC.

**Acceptance Criteria** (cada linha é um padrão EARS):

1. The panel SHALL display each file's size using binary units with base 1024: bytes below 1024 as `B`, then `kB`, `MB`, `GB`, `TB` as the value grows. <!-- ubiquitous -->
2. WHEN a row is a directory OR the `..` entry THEN its size column SHALL be empty (no number). <!-- event-driven -->
3. WHEN the size is a whole number of a unit THEN the panel SHALL show it without a fractional part at that unit boundary (e.g., exactly 1024 bytes → `1 kB`, not `1.0 kB`). <!-- event-driven -->
4. The size formatting SHALL produce at most one decimal digit for non-whole values (e.g., 1.5 MB). <!-- ubiquitous -->

**Independent Test**: Ver um arquivo de ~2 GB exibido como `1.9 GB`, um de ~500 B como `500 B`; pastas e `..` com coluna vazia.

---

## Edge Cases

- IF the current directory is the filesystem root THEN the `..` entry SHALL be absent and `ActivateCursorEntry`/Backspace on an empty root SHALL do nothing (no parent). <!-- unwanted-behavior -->
- WHEN a file's size is exactly 0 bytes THEN the panel SHALL show `0 B`. <!-- event-driven -->
- WHEN the cursor is on `..` and the user presses Up THEN the cursor SHALL stay on `..` (no wrap above the list). <!-- event-driven -->
- WHEN the panel contains only the `..` entry (empty non-root directory) THEN the panel SHALL still show `..` and navigate up correctly. <!-- event-driven -->
- WHEN the user navigates up from a directory whose name matches a parent entry SHALL the cursor land on that exact entry (first match, sorted position). <!-- complex -->
- IF `MarkByPattern` receives a pattern while cursor is on `..` THEN marking SHALL match only real entries. <!-- unwanted-behavior -->

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| PII-01 | P1: Ícone em cada linha | Design | Verified |
| PII-02 | P1: Ícone em cada linha | Design | Verified |
| PII-03 | P1: Ícone em cada linha | Design | Verified |
| PII-04 | P1: Ícone em cada linha | Design | Verified |
| PII-05 | P1: Entrada `..` | Design | Verified |
| PII-06 | P1: Entrada `..` | Design | Verified |
| PII-07 | P1: Entrada `..` | Design | Verified |
| PII-08 | P1: Entrada `..` | Design | Verified |
| PII-09 | P1: Entrada `..` | Design | Verified |
| PII-10 | P1: `..` não marcável | Design | Verified |
| PII-11 | P1: `..` não marcável | Design | Verified |
| PII-12 | P1: `..` não marcável | Design | Verified |
| PII-13 | P1: `..` não marcável | Design | Verified |

| PII-14 | P1: Tamanho formatado | Design | Verified |
| PII-15 | P1: Tamanho formatado | Design | Verified |
| PII-16 | P1: Tamanho formatado | Design | Verified |
| PII-17 | P1: Tamanho formatado | Design | Verified |

**ID format:** `PII-N` (Panel Icons + dotdot)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 17 total, 17 mapped to tasks, 0 unmapped

---

## Success Criteria

- [ ] Executar app: linhas exibem ícone pasta/arquivo; `..` no topo (não-raiz) e ausente na raiz; marcar tudo ignora `..`; voltar com `..` pousa cursor na pasta de origem; tamanhos em kB/MB/GB/TB; pastas/`..` sem tamanho.
- [ ] Testes de Core (marcação), formatação de tamanho e App (PanelViewModel) seguem verdes e cobrem os 17 requisitos.
- [ ] Nenhuma cor nova hardcoded em views (paleta mantida); build com `-warnaserror` limpo.
