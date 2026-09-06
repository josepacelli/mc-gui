# Copy/Move MC Options Specification

## Problem Statement

O diálogo de copiar/mover do MC GUI já resolve conflitos (Overwrite/Skip/Rename/Abort, com "aplicar a todos") e já copia subdiretórios recursivamente. Mas falta paridade com três comportamentos do Midnight Commander original que o usuário usa para decisões de sincronização e preservação de dados: uma opção "Update" que só sobrescreve arquivos mais novos, preservação explícita de atributos/timestamps Unix, e controle sobre seguir ou não links simbólicos. Hoje o app sempre segue links (sem opção) e nunca preserva atributos Unix explicitamente (delega para o comportamento padrão do .NET `File.Copy`).

## Goals

- [ ] O prompt de conflito ganha uma quinta opção "Update", que sobrescreve somente quando a origem é mais nova que o destino.
- [ ] O diálogo de copy/move ganha um checkbox "Preservar atributos", que copia permissões Unix e timestamps originais quando marcado.
- [ ] O diálogo de copy/move ganha um checkbox "Seguir links", que controla se um symlink de origem é copiado como link (não seguido) ou tem seu alvo copiado (seguido).
- [ ] Nenhum comportamento hoje existente (recursão em subdiretórios, Overwrite/Skip/Rename/Abort, progresso, cancelamento) muda quando as novas opções não são usadas.

## Out of Scope

Explicitamente excluído. Documentado para prevenir scope creep.

| Feature | Reason |
| --- | --- |
| Operação em background/fila de jobs | Usuário decidiu não priorizar nesta rodada (backlog separado - menu "Background jobs" já existe desabilitado) |
| Preservação de ACLs/xattrs/resource forks do macOS | Além do escopo de "permissões Unix + timestamp" pedido; complexidade desproporcional ao pedido original |
| "Reget" (retomar transferência parcial) | Recurso do MC ligado a VFS/FTP, que este app ainda não implementa |
| Mudar o mecanismo de prompt de conflito (UI/fluxo) | Reaproveita o `ConflictDialog`/`IConflictPrompt` existente; só adiciona uma opção nova, não redesenha o diálogo |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Onde vive a comparação de "Update" | `MacFileSystemService.ExecuteCopy`/`ExecuteMove` (Infrastructure), comparando `FileEntry.ModifiedUtc` (origem) com `File.GetLastWriteTimeUtc`/`Directory.GetLastWriteTimeUtc` (destino) | Mesma camada que já executa a comparação de conflito hoje (`File.Exists`); não introduz nova abstração | n |
| Valor padrão do checkbox "Preservar atributos" | Desmarcado (OFF) por padrão | Comportamento atual (sem preservação explícita) não muda pra quem não mexe na opção; usuário opta explicitamente, evitando surpresa em cópias comuns | n |
| Valor padrão do checkbox "Seguir links" | Marcado (ON) por padrão | É o comportamento implícito atual do app (`File.Copy` sempre segue o link); manter como padrão evita mudança silenciosa de comportamento pra quem já usa o app | n |
| API usada para preservar permissões Unix | `File.SetUnixFileMode`/`File.GetUnixFileMode` (.NET, disponível desde net7, o projeto usa net10) | Já é BCL padrão, sem P/Invoke customizado; roda só na camada `McGui.Infrastructure.macOS`, conforme AD-001 | n |
| API usada para copiar o symlink em si (sem seguir) | `File.CreateSymbolicLink(destino, alvoOriginal)` (BCL), lendo o alvo via `FileInfo.LinkTarget` do `FileEntry` de origem | BCL padrão, mesma API já usada em `BuildEntry` pra detectar `IsSymlink` | n |
| Falha ao aplicar atributo (ex.: chmod negado) | Registrar em `OperationResult.Skipped` como aviso, não abortar a operação inteira | Mesmo mecanismo hoje usado pra outras falhas de I/O por arquivo (`skipped.Add(...)`); consistente, sem novo tipo de erro | n |
| Symlink quebrado (alvo inexistente) com "Seguir links" marcado | Pular o arquivo, registrar em `Skipped` com motivo "broken symlink" | Não há conteúdo pra copiar quando se segue um link quebrado; falhar seria pior que pular com aviso | n |

**Open questions:** none - todas resolvidas ou registradas acima. Escopo (quais das opções do MC original priorizar) foi decidido pelo usuário: Update-se-mais-novo, preservar atributos, seguir/não-seguir links. Operação em background foi explicitamente descartada desta rodada.

---

## User Stories

### P1: Opção "Update" no prompt de conflito ⭐ MVP

**User Story**: Como usuário, quero uma opção "Update" no prompt de conflito ao copiar/mover, que só sobrescreve o arquivo de destino quando a origem é mais recente, para sincronizar diretórios sem perder versões mais novas já presentes no destino.

**Why P1**: É a opção que o usuário priorizou primeiro; reaproveita 100% o mecanismo de conflito já existente (`IConflictPrompt`, `ApplyToAll`), só adiciona um valor novo ao enum de resolução - menor risco, maior valor imediato.

**Acceptance Criteria**:

1. WHEN um conflito ocorre durante copy/move E o usuário escolhe "Update" no prompt THEN o sistema SHALL comparar `ModifiedUtc` da origem com a data de modificação do destino e sobrescrever somente se a origem for mais recente.
2. IF a origem NÃO for mais recente que o destino (data igual ou mais antiga) THEN o sistema SHALL pular o arquivo, com o mesmo efeito de "Skip", sem erro.
3. WHEN o usuário marca "aplicar a todos" junto com "Update" no primeiro conflito THEN o sistema SHALL aplicar essa mesma regra de comparação a todos os conflitos subsequentes da operação corrente, sem novo prompt.
4. The prompt de conflito SHALL exibir "Update" como uma quinta opção, junto de Overwrite/Skip/Rename/Abort já existentes, sem remover ou reordenar as atuais.

**Independent Test**: Copiar um diretório pra um destino onde 2 arquivos já existem (um mais novo na origem, outro mais novo no destino); no primeiro conflito escolher "Update" + aplicar a todos; confirmar que só o arquivo com origem mais nova foi sobrescrito e o outro permaneceu como estava no destino.

---

### P2: Preservar atributos (permissões Unix + timestamps)

**User Story**: Como usuário, quero um checkbox "Preservar atributos" no diálogo de copy/move, para manter as permissões Unix e a data de modificação original no destino, igual ao `cp -p` do MC original.

**Why P2**: Depende só da infraestrutura de cópia por arquivo já existente; não depende de P1/P3, mas é mais específico de nicho (usuários que se importam com permissões exatas) que a opção Update.

**Acceptance Criteria**:

1. WHILE o checkbox "Preservar atributos" estiver marcado no diálogo THEN, após cada arquivo copiado ou movido (via fallback copy+delete entre volumes), o sistema SHALL aplicar ao destino o mesmo `ModifiedUtc` e o mesmo modo de permissões Unix (`UnixFileMode`) da origem.
2. WHILE o checkbox estiver desmarcado THEN o sistema SHALL manter o comportamento padrão atual, sem nenhuma chamada adicional de preservação de atributo.
3. The diálogo de copy/move SHALL exibir o checkbox "Preservar atributos", desmarcado por padrão (ver Assumptions).
4. IF a aplicação de um atributo falhar (ex.: permissão negada) THEN o sistema SHALL registrar o arquivo em `OperationResult.Skipped` com o motivo da falha, sem abortar o restante da operação.

**Independent Test**: Copiar um arquivo com permissão `600` e timestamp antigo, com "Preservar atributos" marcado; confirmar no destino que `ls -l` mostra a mesma permissão e a mesma data de modificação da origem (não a data/hora da cópia).

---

### P3: Seguir ou não links simbólicos

**User Story**: Como usuário, quero um checkbox "Seguir links" no diálogo de copy/move, para escolher entre copiar o link simbólico em si ou copiar o conteúdo do arquivo/diretório que ele aponta, igual ao MC original.

**Why P3**: Puramente aditivo - hoje o app sempre segue links implicitamente; adicionar a opção não quebra nenhum fluxo existente, e é o cenário menos comum entre os três (a maioria dos arquivos copiados não é symlink).

**Acceptance Criteria**:

1. WHILE o checkbox "Seguir links" estiver desmarcado E a entrada de origem for um symlink (`FileEntry.IsSymlink == true`) THEN o sistema SHALL criar no destino um novo symlink apontando para o mesmo alvo do link de origem, sem copiar o conteúdo do alvo.
2. WHILE o checkbox "Seguir links" estiver marcado E a entrada de origem for um symlink THEN o sistema SHALL copiar o conteúdo do arquivo ou diretório apontado pelo link (comportamento atual, hoje implícito).
3. The diálogo de copy/move SHALL exibir o checkbox "Seguir links", marcado por padrão (ver Assumptions - preserva o comportamento implícito de hoje).
4. IF o link simbólico de origem estiver quebrado (alvo inexistente) E "Seguir links" estiver marcado THEN o sistema SHALL pular o arquivo, registrando em `OperationResult.Skipped` com o motivo "broken symlink", sem lançar exceção não tratada.

**Independent Test**: Criar um symlink apontando para um arquivo, copiar com "Seguir links" desmarcado - confirmar que o destino é um novo symlink (não uma cópia do conteúdo); repetir com "Seguir links" marcado - confirmar que o destino é uma cópia real do conteúdo apontado.

---

## Edge Cases

- IF o destino já tem uma entrada com o mesmo nome (symlink ou não) THEN o fluxo de conflito já existente (Overwrite/Skip/Rename/Update/Abort) SHALL se aplicar normalmente, independente das opções de atributo/link estarem marcadas.
- IF "Preservar atributos" está marcado mas o sistema de arquivos de destino não suporta permissões Unix (ex.: volume FAT/exFAT montado) THEN o sistema SHALL aplicar o timestamp quando possível e registrar a falha de permissão como aviso (mesmo mecanismo do AC4 de P2), sem abortar a operação inteira.
- WHEN o Move usa o fallback de copy+delete entre volumes (caminho já existente em `MoveEntry`) THEN as opções de atributo/symlink SHALL se aplicar igualmente a esse caminho, não só ao `File.Copy` direto.
- WHEN as três opções desta feature não são tocadas pelo usuário (valores padrão) THEN nenhum teste de regressão da suite atual (219 testes) SHALL falhar.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| CPMV-01 | P1: Opção Update | Design | Pending |
| CPMV-02 | P1: Opção Update | Design | Pending |
| CPMV-03 | P1: Opção Update | Design | Pending |
| CPMV-04 | P1: Opção Update | Design | Pending |
| CPMV-05 | P2: Preservar atributos | Design | Pending |
| CPMV-06 | P2: Preservar atributos | Design | Pending |
| CPMV-07 | P2: Preservar atributos | Design | Pending |
| CPMV-08 | P2: Preservar atributos | Design | Pending |
| CPMV-09 | P3: Seguir links | Design | Pending |
| CPMV-10 | P3: Seguir links | Design | Pending |
| CPMV-11 | P3: Seguir links | Design | Pending |
| CPMV-12 | P3: Seguir links | Design | Pending |

**ID format:** `CPMV-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 12 total, 0 mapped to tasks, 12 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] Prompt de conflito mostra "Update" e aplica a regra "sobrescreve só se mais novo" corretamente, sozinho e com "aplicar a todos".
- [ ] Checkbox "Preservar atributos" reproduz permissão Unix e timestamp originais no destino quando marcado; comportamento atual inalterado quando desmarcado.
- [ ] Checkbox "Seguir links" copia o link em si quando desmarcado e o conteúdo apontado quando marcado (padrão), sem exceção em link quebrado.
- [ ] Recursão em subdiretórios, conflitos existentes (Overwrite/Skip/Rename/Abort), progresso e cancelamento continuam funcionando sem regressão.
- [ ] Suite de testes existente (219 testes) continua passando; novos testes cobrem as 3 opções (unit no `McGui.Core.Tests`/`McGui.Infrastructure.macOS.Tests`, estrutural nos diálogos em `McGui.App.Tests`).
