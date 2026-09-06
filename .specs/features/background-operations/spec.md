# Background Operations Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje executa operações de arquivo (copiar, mover, apagar) de forma síncrona com diálogo de progresso modal — o usuário não pode fazer nada até a operação terminar. O Midnight Commander original possui operações em background (Background jobs): ao copiar/mover/apagar, o usuário pode pressionar `Esc` ou `F2` para enviar a operação para background, continuando a usar o MC enquanto a operação roda. O menu `Command > Background jobs` mostra a lista de jobs ativos com progresso, permitindo suspender, retomar, cancelar, ou ver detalhes. Esta feature entrega o sistema de background operations no mc-gui: fila de jobs (copy/move/delete), execução assíncrona com progresso em background, janela/panel de jobs ativos, controle por job (pause/resume/cancel), e notificações de conclusão.

## Goals

- [ ] Operações de arquivo (Copy, Move, Delete) ganham opção "Background" no diálogo de confirmação (checkbox ou botão "Send to background").
- [ ] Quando marcada, a operação inicia em background: diálogo de progresso fecha, usuário volta ao painel imediatamente.
- [ ] Janela/Menu `Command > Background jobs` (habilitado) mostra lista de jobs ativos/concluídos com: tipo (Copy/Move/Delete), fonte→destino, progresso (%), velocidade, tempo restante, status (Running/Paused/Completed/Failed).
- [ ] Controles por job: Pause (suspende I/O), Resume (retoma), Cancel (aborta com limpeza), Show details (abre log/erros).
- [ ] Jobs rodam em thread pool dedicado (limite configurável, ex.: 2 jobs simultâneos de copy/move, 1 de delete).
- [ ] Persistência de fila: jobs sobrevivem a restart do app (serializados em config); jobs incompletos retomam ou marcam como failed.
- [ ] Notificação toast/sistema quando job completa (sucesso ou falha); clique na notificação abre detalhes.
- [ ] Integração com operações existentes: Copy/Move/Delete dialogs ganham checkbox "Background"; atalho `F2` no progress dialog envia para background.
- [ ] Menu `Command > Background jobs` habilitado; atalho (ex.: `Ctrl+J`) abre janela de jobs.

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Reget (retomar transferência parcial FTP/HTTP) | Exige suporte a range requests no VFS; feature futura |
| Agendamento de jobs (run at time, cron-like) | Fora do escopo de gerenciador de arquivos |
| Prioridade de I/O (ionice) | Específico de SO; nice-to-have |
| Jobs de compressão/extração (tar, zip) | Feature separada (VFS write) |
| Sincronização de diretórios (rsync-like) | Feature futura (compare dirs + background) |
| Jobs de busca (find file em background) | Find file já é assíncrono; não precisa de job queue |
| UI de log detalhado por arquivo (skip reasons) | Progress dialog já mostra; background job summary suficiente |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Arquitetura | `IBackgroundJobService` no Core; implementação em `McGui.Infrastructure.macOS` com `BackgroundJobQueue` + `BackgroundJob` records | AD-001; isolamento de SO | n |
| Job types | `CopyJob`, `MoveJob`, `DeleteJob` (herdam de `BackgroundJob` base) | Extensível para futuros tipos | n |
| Persistência | JSON em `~/.config/mc-gui/background-jobs.json`; carrega no startup, salva on-change | Simples, legível | n |
| Thread pool | `TaskPool` com `MaxDegreeOfParallelism` configurável (default: 2 copy/move, 1 delete) | Evita saturação de disco | n |
| Pause/Resume | `CancellationToken` + `ManualResetEventSlim` por job; pause = não processa próximo chunk; resume = sinaliza evento | Simples, cooperativo | n |
| UI de jobs | Janela separada (`Window`) modeless, dockable à direita ou flutuante; `DataGrid` com colunas fixas | Modeless permite usar painéis enquanto monitora | n |
| Notificações | `INotificationService` no Core; macOS: `NSUserNotification` / `UserNotifications`; Windows: Toast; Linux: `libnotify` | AD-001 | n |
| Integração Copy/Move/Delete | `CopyMoveDialogViewModel` ganha `IsBackground` property; `ConfirmAsync` enfileira job em vez de executar síncrono | Mínima mudança no fluxo existente | n |
| Testes | Unit: JobQueue, Job persistence, Pause/Resume logic; Integration: enfileirar copy, verificar progresso background, cancelar; UAT: janela jobs | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Enviar operação para background ⭐ MVP

**User Story**: Como usuário, quero marcar "Background" no diálogo de copiar/mover/apagar e continuar trabalhando nos painéis enquanto a operação roda, para não perder tempo esperando.

**Why P1**: Diferencial principal do MC original; uso diário para cópias grandes.

**Acceptance Criteria**:

1. WHEN the user opens Copy/Move/Delete dialog THEN a checkbox "Run in background" SHALL be present (unchecked by default).
2. WHEN the user checks "Run in background" and confirms THEN the operation SHALL be enqueued as a background job, the confirmation dialog SHALL close immediately, and the user SHALL regain control of the panels.
3. THE Background Jobs window (Command > Background jobs) SHALL show the new job with status "Running" and progress 0%.
4. WHEN the job completes successfully THEN a system notification SHALL appear "Copy completed: X files, Y MB"; clicking it opens job details.
5. IF the job fails THEN notification SHALL show "Copy failed: [error]" with option to retry or view log.

**Independent Test**: Copiar pasta 1GB com "Background" checked → dialog fecha, painéis livres; abre Background Jobs → job rodando; notificação ao fim.

---

### P1: Janela de Background Jobs com controles ⭐ MVP

**User Story**: Como usuário, quero ver todos meus jobs em background, pausar/retomar/cancelar, e ver detalhes de erros, para gerenciar transferências longas.

**Why P1**: Controle granular é essencial para operações longas/unreliable (rede, discos lentos).

**Acceptance Criteria**:

1. THE `Command > Background jobs` menu item SHALL be enabled and open a modeless "Background Jobs" window.
2. THE window SHALL display a list/grid with columns: Type (icon), Source → Destination, Progress (%), Speed, ETA, Status, Actions.
3. WHEN the user selects a job and clicks "Pause" THEN the job SHALL suspend I/O (worker checks pause token before each chunk); status changes to "Paused"; button changes to "Resume".
4. WHEN the user clicks "Resume" on a paused job THEN the job SHALL continue from where it stopped; status "Running".
5. WHEN the user clicks "Cancel" THEN the job SHALL abort: cleanup partial files (for copy/move), status "Cancelled", removed from active list after 5s.
6. WHEN the user double-clicks a job or clicks "Details" THEN a detail pane/window SHALL show: full source/dest paths, file list (for copy/move), error log (if failed), timestamps.

**Independent Test**: Iniciar 2 copies grandes em background; Pause um → para; Resume → continua; Cancel o outro → limpa parciais; Details mostra log.

---

### P1: Persistência e recuperação de jobs ⭐ MVP

**User Story**: Como usuário, quero que meus jobs em background sobrevivam se eu fechar/abrir o app acidentalmente, para não perder transferências longas.

**Why P1**: Confiabilidade; MC original não persistia jobs (processo fork), mas GUI moderna deve.

**Acceptance Criteria**:

1. THE job queue SHALL be serialized to `background-jobs.json` on every change (enqueue, progress update, completion).
2. ON application startup, the queue SHALL be deserialized; jobs with status "Running" or "Paused" SHALL be restored to "Paused" (user must manually Resume).
3. COMPLETED/FAILED jobs SHALL be kept in history for 7 days (configurable) then auto-purged.
4. IF the config file is corrupted THEN the app SHALL start with empty queue and log warning.

**Independent Test**: Iniciar copy background, fechar app, reabrir → job aparece como "Paused"; Resume → continua.

---

### P2: Integração transparente com operações existentes ⭐ MVP

**User Story**: Como usuário, quero que o fluxo atual de copiar/mover/apagar continue funcionando igual (síncrono) se eu não marcar Background, para não quebrar meu workflow atual.

**Why P2**: Não-regressão; Background é opt-in.

**Acceptance Criteria**:

1. WHEN "Run in background" is UNCHECKED (default) THEN Copy/Move/Delete SHALL behave exactly as today: modal progress dialog, blocks panels until done.
2. THE "Run in background" checkbox SHALL be clearly labeled and placed near the Confirm/Cancel buttons.
3. KEYBOARD shortcut in progress dialog: `F2` or `Ctrl+B` toggles "Send to background" (moves running operation to job queue).
4. IF an operation is already running modally and user presses `F2` THEN it SHALL seamlessly transition to background job (progress dialog closes, job appears in queue).

---

## Edge Cases

- IF the user tries to enqueue more jobs than thread pool limit THEN excess jobs SHALL stay "Queued" until a slot frees; UI shows queue position.
- IF a background job tries to write to a destination that becomes full THEN job fails with "Disk full" error; partial files cleaned up; user notified.
- IF the user cancels a Move job that already moved some files THEN those files SHALL remain at destination (no rollback for move — same as current behavior).
- IF the app crashes during background job THEN on restart the job SHALL be "Paused" with partial progress; user decides to Resume or Cancel.
- CONCURRENT jobs writing to same destination directory SHALL serialize per-directory (lock) to avoid corruption.
- NETWORK jobs (FTP/SFTP via VFS) SHALL respect pause/cancel via VFS layer cancellation tokens.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| BGO-01 | P1: Enviar p/ background | Specify | Pending |
| BGO-02 | P1: Enviar p/ background | Specify | Pending |
| BGO-03 | P1: Enviar p/ background | Specify | Pending |
| BGO-04 | P1: Enviar p/ background | Specify | Pending |
| BGO-05 | P1: Enviar p/ background | Specify | Pending |
| BGO-06 | P1: Janela Jobs + controles | Specify | Pending |
| BGO-07 | P1: Janela Jobs + controles | Specify | Pending |
| BGO-08 | P1: Janela Jobs + controles | Specify | Pending |
| BGO-09 | P1: Janela Jobs + controles | Specify | Pending |
| BGO-10 | P1: Janela Jobs + controles | Specify | Pending |
| BGO-11 | P1: Persistência | Specify | Pending |
| BGO-12 | P1: Persistência | Specify | Pending |
| BGO-13 | P1: Persistência | Specify | Pending |
| BGO-14 | P1: Persistência | Specify | Pending |
| BGO-15 | P2: Integração transparente | Specify | Pending |
| BGO-16 | P2: Integração transparente | Specify | Pending |
| BGO-17 | P2: Integração transparente | Specify | Pending |
| BGO-18 | P2: Integração transparente | Specify | Pending |

**ID format:** `BGO-NN` (Background Operations)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 18 total, 0 mapped to tasks, 18 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] Copy/Move/Delete dialog tem checkbox "Run in background"; checked → enfileira job, dialog fecha, painéis livres.
- [ ] `Command > Background jobs` abre janela modeless com lista de jobs; Pause/Resume/Cancel/Details funcionam.
- [ ] Jobs persistem em JSON; restart → jobs "Running" viram "Paused"; Resume continua.
- [ ] Notificação toast ao completar/falhar; clique abre details.
- [ ] Modo síncrono (default) inalterado; F2 no progress dialog migra para background.
- [ ] Thread pool respeita limites; jobs em fila aguardam slot.
- [ ] Suite de testes existente (236) continua passando; novos testes: unit JobQueue, integração background copy.
- [ ] Build com `-warnaserror` limpo.