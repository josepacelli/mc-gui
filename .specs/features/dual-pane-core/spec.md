# Dual-Pane Core Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O Midnight Commander (MC) é um gerenciador de arquivos dual-pane de terminal, sem interface gráfica nativa, o que limita seu uso em fluxos modernos de desktop (mouse, drag&drop, telas de alta resolução, integração com o SO). O objetivo do projeto `mc-gui` é entregar um clone funcional do MC com interface gráfica nativa multiplataforma (Windows/macOS/Linux), construído do zero em C#/Avalonia, preservando a identidade de navegação clássica do MC (dois painéis, barra de F-keys, keybindings estilo Emacs) mas com os benefícios de uma GUI moderna (Fluent Design, mouse, drag&drop).

Esta especificação cobre apenas a primeira fatia entregável (MVP): navegação dual-pane e operações de arquivo **locais** (copiar, mover, renomear, apagar, criar diretório, seleção múltipla), **entregue primeiro para macOS**. Windows e Linux reaproveitam a mesma base Avalonia em features/fases futuras. Funcionalidades como editor embutido, visualizador de arquivos, VFS remoto (FTP/SFTP/SSH), navegação em arquivos compactados, subshell e skins ficam fora desta feature e serão especificadas separadamente.

## Goals

- [ ] Usuário navega entre dois painéis e dentro de diretórios locais usando exclusivamente o teclado, com keybindings compatíveis com o MC clássico (F2-F10, Tab, setas, Emacs-style).
- [ ] Usuário realiza copiar/mover/renomear/apagar/criar-diretório com confirmação e tratamento de conflitos, sem perda de dados silenciosa.
- [ ] Aplicação roda em macOS nesta primeira versão; a base de código (Avalonia + abstração de sistema de arquivos) permanece multiplataforma para portar a Windows/Linux em features futuras sem reescrita.

## Out of Scope

Explicitamente excluído desta feature. Cada item será uma feature futura própria.

| Feature | Motivo |
| --- | --- |
| Editor de texto embutido (F4) | Feature separada; F4 aparece na barra mas fica desabilitado nesta versão |
| Visualizador de arquivos texto/hex (F3) | Feature separada; F3 aparece na barra mas fica desabilitado nesta versão |
| VFS remoto (FTP/SFTP/SSH) | Fora do MVP; exige integração de rede/credenciais própria |
| Navegação dentro de arquivos compactados (tar/zip/rpm/cpio/lha/rar) | Depende de VFS; feature separada |
| Subshell embutido (prompt de shell real na UI) | Alta complexidade multiplataforma (PTY em Windows); feature separada |
| Skins/temas customizáveis além de claro/escuro padrão do Avalonia | Não bloqueia o MVP de navegação/operações |
| Hotlist/bookmarks, Learn Keys, menu de usuário (F2) customizável | Conveniências de fases posteriores |
| Operações em background (cópia assíncrona com fila de jobs) | Nesta feature, cópia/move são síncronas com diálogo de progresso cancelável |
| Importação de configuração/skins de instalações reais do MC | Não é requisito do MVP |
| Find-file por conteúdo, external panelization, FTP proxy | Fora do MVP |

---

## Assumptions & Open Questions

Toda ambiguidade foi resolvida ou registrada aqui - nada fica silenciosamente indefinido.

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Exclusão de arquivos (F8) usa lixeira/reciclagem do SO quando disponível | Mover para lixeira/Recycle Bin por padrão; `Shift`+confirmar apaga permanentemente | O MC original em console não tem conceito de lixeira; numa GUI moderna, exclusão acidental irreversível é um risco de segurança/UX que a lixeira mitiga sem quebrar a fidelidade ao fluxo F8 | n |
| Comportamento em links simbólicos | Mover/Apagar atuam sobre o link; Copiar segue o alvo do link | Replica o comportamento documentado do MC clássico para VFS/links | n |
| Cópia/Move são operações síncronas nesta feature (sem fila de background) | Diálogo de progresso modal com Cancelar | Fila de jobs em background é um recurso do MC original mas aumenta muito o escopo de engenharia; adiado para feature futura | n |
| Sem log persistente de auditoria de operações no MVP | Erros reportados apenas via diálogo, sem arquivo de log dedicado | Não há requisito de observabilidade citado pelo usuário; diálogos de erro já cobrem o caso de uso do MVP | n |
| F3 (Ver) e F4 (Editar) permanecem visíveis na barra de function-keys, porém desabilitados | Barra de 10 F-keys sempre visível, com F3/F4 em estado disabled | Mantém a identidade visual clássica do "clone" sem implementar funcionalidade fora de escopo desta feature | n |
| Diretório inicial de cada painel no primeiro lançamento (sem estado salvo) | Diretório home do usuário do SO em ambos os painéis | Comportamento padrão razoável e multiplataforma | n |
| Ordem de entrega das plataformas alvo | Primeira versão (esta feature) roda e é validada apenas em macOS; Windows e Linux entram em features/fases futuras usando a mesma base Avalonia | Reduz superfície de teste/validação do MVP; Avalonia já garante portabilidade futura sem retrabalho arquitetural | y (confirmado pelo usuário) |
| Multi-usuário / autenticação | N/A para esta feature | Aplicação desktop de usuário único operando sobre o sistema de arquivos local; controle de acesso já é feito pelo SO | n |
| Dependência externa (rede, VFS remoto) | N/A para esta feature | FTP/SFTP/SSH/archives ficam fora de escopo desta feature (ver Out of Scope) | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Navegação dual-pane ⭐ MVP

**User Story**: Como usuário do gerenciador de arquivos, quero navegar por dois painéis de diretório lado a lado usando o teclado, para me deslocar rapidamente pela árvore de arquivos local sem tocar no mouse.

**Why P1**: É a fundação de qualquer operação subsequente (copiar, mover, etc.) - sem navegação dual-pane não há produto demonstrável.

**Acceptance Criteria**:

1. WHEN the application starts THEN the system SHALL display two side-by-side panels, each listing the contents of a directory.
2. WHEN the user presses Tab THEN the system SHALL move keyboard focus to the other panel and visually highlight the newly active panel's border.
3. WHEN the active panel has focus and the user presses the Up or Down arrow key THEN the system SHALL move the selection cursor to the previous or next entry, stopping (not wrapping) at the first or last entry.
4. WHEN the user presses Enter on a directory entry THEN the system SHALL change the active panel's current directory to that subdirectory and refresh its listing.
5. WHEN the user presses Backspace or activates the ".." entry THEN the system SHALL navigate the active panel to its parent directory.
6. WHILE a panel's directory listing takes longer than 500 ms to load THEN the system SHALL show a loading indicator inside that panel.
7. WHEN the application closes normally THEN the system SHALL persist each panel's current directory path to user configuration for restoration on next launch.
8. IF a panel's persisted directory path does not exist at launch THEN the system SHALL fall back to the user's home directory for that panel.

**Independent Test**: Abrir o app, ver dois painéis com o diretório home; Tab alterna o foco; Enter entra em uma subpasta; reiniciar o app restaura os dois diretórios usados por último.

---

### P1: Seleção múltipla de arquivos ⭐ MVP

**User Story**: Como usuário, quero marcar múltiplos arquivos/pastas de uma vez, para aplicar copiar/mover/apagar sobre um lote em vez de um item por vez.

**Why P1**: Toda operação de arquivo (copiar/mover/apagar) opera sobre a seleção; sem isso as demais stories não têm sobre o que atuar em lote.

**Acceptance Criteria**:

1. WHEN the user presses Insert or Space on an entry THEN the system SHALL toggle that entry's marked state and move the cursor to the next entry.
2. WHEN the user presses "+" and enters a glob pattern THEN the system SHALL mark every entry in the active panel whose name matches that pattern.
3. WHEN the user presses "-" and enters a glob pattern THEN the system SHALL unmark every entry in the active panel whose name matches that pattern.
4. WHEN the user presses "*" THEN the system SHALL invert the marked state of every entry in the active panel.
5. The system SHALL display, in the active panel's status line, a running count and total byte size of the currently marked entries.

**Independent Test**: Marcar arquivos individualmente com Insert, marcar por padrão com "+", inverter com "*"; conferir que a contagem/tamanho na status line muda a cada ação.

---

### P1: Copiar arquivos (F5) ⭐ MVP

**User Story**: Como usuário, quero copiar os arquivos/pastas selecionados para o diretório do painel oposto, para duplicar conteúdo sem sair do teclado.

**Why P1**: Copiar é a operação de arquivo mais usada em um gerenciador dual-pane; é parte do vertical slice mínimo demonstrável.

**Acceptance Criteria**:

1. WHEN the user presses F5 with one or more entries marked, or with none marked and a cursor entry present, THEN the system SHALL open a copy confirmation dialog pre-filled with the opposite panel's current directory as the destination, editable by the user.
2. WHEN the user confirms the copy dialog THEN the system SHALL copy every selected entry, recursively for directories, to the destination path and SHALL show a progress dialog with percentage complete, current file name, and a Cancel button.
3. IF a destination entry with the same name already exists THEN the system SHALL prompt Overwrite, Skip, Rename, or Abort, with an "apply to all" option, before writing that entry.
4. WHEN the user clicks Cancel during a copy operation THEN the system SHALL stop after the current file finishes and SHALL leave already-copied files in place without rollback.
5. IF the destination path is the source path itself or a subdirectory of it THEN the system SHALL reject the operation with an error message identifying the circular copy.
6. IF the destination volume lacks enough free space for the total marked size THEN the system SHALL abort before starting and SHALL show the required and available byte counts.

**Independent Test**: Copiar um arquivo e uma pasta com subarquivos entre os painéis e conferir o conteúdo; forçar um conflito de nome e testar Overwrite/Skip; cancelar uma cópia em andamento.

---

### P1: Mover / Renomear arquivos (F6) ⭐ MVP

**User Story**: Como usuário, quero mover os arquivos selecionados para o painel oposto ou renomear um único arquivo no lugar, para reorganizar minha árvore de arquivos.

**Why P1**: Mover/renomear é operação básica esperada de qualquer gerenciador de arquivos e reaproveita as regras de conflito da story de Copiar.

**Acceptance Criteria**:

1. WHEN the user presses F6 with entries marked (or the cursor entry) and confirms the destination dialog THEN the system SHALL move every selected entry to the destination path, applying the same Overwrite/Skip/Rename/Abort and free-space rules used for Copy.
2. WHEN exactly one entry is selected and the user edits only the file name in the dialog without changing the destination directory THEN the system SHALL rename the entry in place instead of performing a full move.
3. IF the user attempts to move a directory into itself or into one of its own subdirectories THEN the system SHALL reject the operation with an error message.
4. IF the entry being moved is the current directory shown in the other panel THEN the system SHALL block the operation and SHALL explain why before starting.

**Independent Test**: Renomear um único arquivo no lugar; mover um arquivo entre painéis; tentar mover uma pasta para dentro dela mesma e confirmar a rejeição.

---

### P1: Criar diretório (F7) ⭐ MVP

**User Story**: Como usuário, quero criar uma nova pasta dentro do painel ativo, para organizar arquivos sem sair do teclado.

**Why P1**: Operação básica e de baixo custo de implementação, completa o conjunto mínimo de operações de arquivo do MVP.

**Acceptance Criteria**:

1. WHEN the user presses F7 THEN the system SHALL prompt for a new folder name and SHALL create it inside the active panel's current directory upon confirmation.
2. IF the entered name already exists in the current directory THEN the system SHALL reject it with an inline error and SHALL keep the dialog open for correction.
3. IF the entered name contains characters invalid for the host operating system's file system THEN the system SHALL reject it with an inline error identifying the invalid character before attempting creation.

**Independent Test**: Criar uma pasta nova; tentar criar com nome duplicado; tentar criar com caractere inválido para o SO em uso.

---

### P1: Apagar arquivos (F8) ⭐ MVP

**User Story**: Como usuário, quero apagar os arquivos/pastas selecionados com uma rede de segurança contra exclusão acidental, para manter meus dados protegidos.

**Why P1**: Completa o ciclo básico de CRUD de arquivos; a rede de segurança (lixeira) é o ajuste de fidelidade "clone + GUI moderna" definido nas Assumptions.

**Acceptance Criteria**:

1. WHEN the user presses F8 with entries marked (or the cursor entry) THEN the system SHALL show a confirmation dialog listing the count and total size of the entries to delete.
2. WHEN the user confirms deletion AND the host operating system provides a trash or recycle bin THEN the system SHALL move the confirmed entries to that trash or recycle bin instead of deleting them permanently.
3. WHERE the host operating system has no trash or recycle bin available THEN the system SHALL permanently delete the confirmed entries.
4. WHEN the user holds Shift while confirming deletion THEN the system SHALL permanently delete the entries, bypassing trash, and SHALL show wording in the dialog stating the action is irreversible.
5. IF an entry cannot be deleted due to an operating system permission error THEN the system SHALL skip that entry, SHALL continue processing the remaining entries, and SHALL report the failed entry's path and reason once the operation finishes.

**Independent Test**: Apagar um arquivo e confirmar que ele aparece na lixeira do SO; Shift+apagar um arquivo e confirmar que não passa pela lixeira; apagar um arquivo somente-leitura e conferir que é pulado e reportado.

---

### P2: Produtividade no painel

**User Story**: Como usuário frequente, quero ordenar, filtrar rapidamente e atualizar os painéis, para localizar arquivos mais rápido em diretórios grandes.

**Why P2**: Melhora a experiência de uso diário, mas o MVP funciona sem isso (usuário ainda navega manualmente).

**Acceptance Criteria**:

1. WHEN the user presses Ctrl+R THEN the system SHALL re-read the active panel's directory from disk and SHALL refresh its listing.
2. WHEN the user types printable characters while a panel has focus and no dialog is open THEN the system SHALL filter that panel's listing to entries whose name contains the typed text, case-insensitively.
3. WHEN the user activates a column header (Name, Size, or Date) THEN the system SHALL sort the active panel by that column, toggling between ascending and descending on repeated activations.
4. WHEN the user presses Ctrl+H THEN the system SHALL toggle the visibility of hidden entries (dotfiles) in both panels.
5. The system SHALL always list the ".." entry first in a panel whenever the panel's current directory is not a file system root.

---

### P3: Conveniências extras

**User Story**: Como usuário avançado, quero atalhos adicionais (troca de painéis, drag&drop, pré-visualização), para operar de forma ainda mais fluida.

**Why P3**: Agrega valor, mas nenhuma dessas ações é necessária para demonstrar ou usar o produto no dia a dia.

**Acceptance Criteria**:

1. WHEN the user presses Ctrl+U THEN the system SHALL swap the current directories shown in the two panels.
2. WHEN the user drags a marked entry from one panel and drops it on the other panel THEN the system SHALL perform a Move if both panels are on the same volume, or a Copy if they are on different volumes, following the same confirmation flow used for F5/F6.
3. WHEN the user presses Ctrl+X then Q THEN the system SHALL toggle a quick-preview area showing the beginning of the cursor entry's content when it is a plain-text file.

---

## Edge Cases

- IF the active panel's current directory becomes inaccessible while displayed (e.g., a removable drive is unplugged) THEN the system SHALL show an inline error state in that panel and SHALL offer a "go to home directory" action.
- IF the user attempts an operation (copy/move/delete) targeting zero entries (no marks and no cursor entry, e.g. empty directory) THEN the system SHALL do nothing and SHALL NOT open a confirmation dialog.
- WHEN a marked entry is a symbolic link THEN Move and Delete SHALL operate on the link itself, and Copy SHALL follow the link's target, per the Assumptions table.
- IF an entered destination path in a Copy/Move dialog does not exist THEN the system SHALL offer to create it as part of confirming the dialog, rather than failing silently.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| DPC-01 | P1: Navegação dual-pane | Design | Pending |
| DPC-02 | P1: Navegação dual-pane | Design | Pending |
| DPC-03 | P1: Navegação dual-pane | Design | Pending |
| DPC-04 | P1: Navegação dual-pane | Design | Pending |
| DPC-05 | P1: Navegação dual-pane | Design | Pending |
| DPC-06 | P1: Navegação dual-pane | Design | Pending |
| DPC-07 | P1: Navegação dual-pane | Design | Pending |
| DPC-08 | P1: Navegação dual-pane | Design | Pending |
| DPC-09 | P1: Seleção múltipla de arquivos | Tasks (T6) | Implementing |
| DPC-10 | P1: Seleção múltipla de arquivos | Tasks (T6) | Implementing |
| DPC-11 | P1: Seleção múltipla de arquivos | Tasks (T6) | Implementing |
| DPC-12 | P1: Seleção múltipla de arquivos | Tasks (T6) | Implementing |
| DPC-13 | P1: Seleção múltipla de arquivos | Tasks (T6) | Implementing |
| DPC-14 | P1: Copiar arquivos (F5) | Design | Pending |
| DPC-15 | P1: Copiar arquivos (F5) | Design | Pending |
| DPC-16 | P1: Copiar arquivos (F5) | Design | Pending |
| DPC-17 | P1: Copiar arquivos (F5) | Design | Pending |
| DPC-18 | P1: Copiar arquivos (F5) | Design | Pending |
| DPC-19 | P1: Copiar arquivos (F5) | Design | Pending |
| DPC-20 | P1: Mover / Renomear arquivos (F6) | Design | Pending |
| DPC-21 | P1: Mover / Renomear arquivos (F6) | Design | Pending |
| DPC-22 | P1: Mover / Renomear arquivos (F6) | Design | Pending |
| DPC-23 | P1: Mover / Renomear arquivos (F6) | Design | Pending |
| DPC-24 | P1: Criar diretório (F7) | Design | Pending |
| DPC-25 | P1: Criar diretório (F7) | Design | Pending |
| DPC-26 | P1: Criar diretório (F7) | Design | Pending |
| DPC-27 | P1: Apagar arquivos (F8) | Design | Pending |
| DPC-28 | P1: Apagar arquivos (F8) | Design | Pending |
| DPC-29 | P1: Apagar arquivos (F8) | Design | Pending |
| DPC-30 | P1: Apagar arquivos (F8) | Design | Pending |
| DPC-31 | P1: Apagar arquivos (F8) | Design | Pending |
| DPC-32 | P2: Produtividade no painel | - | Pending |
| DPC-33 | P2: Produtividade no painel | - | Pending |
| DPC-34 | P2: Produtividade no painel | - | Pending |
| DPC-35 | P2: Produtividade no painel | - | Pending |
| DPC-36 | P2: Produtividade no painel | - | Pending |
| DPC-37 | P3: Conveniências extras | - | Pending |
| DPC-38 | P3: Conveniências extras | - | Pending |
| DPC-39 | P3: Conveniências extras | - | Pending |

**ID format:** `DPC-NN` (Dual-Pane Core)

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 39 total, 0 mapped to tasks, 39 unmapped ⚠️ (mapeamento acontece na fase Tasks)

---

## Success Criteria

- [ ] Usuário completa, apenas com teclado, o ciclo navegar → marcar → copiar/mover/apagar → criar pasta em ambos os painéis, rodando em macOS.
- [ ] Todos os 31 critérios de aceite do P1 (DPC-01 a DPC-31) possuem teste automatizado passando.
- [ ] Nenhuma operação de exclusão contorna a lixeira do SO (macOS Trash) sem o usuário segurar Shift explicitamente.
- [ ] Aplicação restaura corretamente os diretórios dos dois painéis após reiniciar, em macOS.
- [ ] Nenhuma dependência específica de macOS é introduzida fora da camada de abstração de sistema de arquivos/SO, preservando a portabilidade futura para Windows/Linux.
