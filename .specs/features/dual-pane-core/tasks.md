# Dual-Pane Core Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/dual-pane-core/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Gerado sem amostragem de código (repositório novo, sem testes/guidelines existentes) - framework de teste (xUnit) e ferramentas confirmados com o usuário na fase Tasks. Confirmar antes do Execute.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| `McGui.Core` - modelos de dados (`FileEntry`, `PanelState`, enums, `CopyMovePlan`, `OperationProgress`, `OperationResult`, `PanelPathHistory`) | none | build gate only (sem lógica) | `src/McGui.Core/Models/**/*.cs` | build gate only |
| `McGui.Core` - contratos (`IFileSystemService`, `ITrashService`, `IPathHistoryStore`) | none | build gate only (sem lógica) | `src/McGui.Core/Interfaces/**/*.cs` | build gate only |
| `McGui.Core` - lógica de domínio (`SelectionService`, `CopyMovePlanner`) | unit | Todos os ramos; 1:1 com DPC-09..13, DPC-18, DPC-22, DPC-23; todo edge case listado no spec tem teste | `tests/McGui.Core.Tests/**/*.cs` | `dotnet test tests/McGui.Core.Tests/McGui.Core.Tests.csproj` |
| `McGui.Infrastructure.macOS` (filesystem, trash, path-history) | integration | Caminhos-chave (listar/copiar/mover/mkdir/lixeira/persistir) + todo caminho de erro documentado no design (permissão negada, disco cheio, colisão de nome) | `tests/McGui.Infrastructure.macOS.Tests/**/*.cs` | `dotnet test tests/McGui.Infrastructure.macOS.Tests/McGui.Infrastructure.macOS.Tests.csproj` |
| `McGui.App` - ViewModels (Panel/CopyMove/Delete/Mkdir/Progress) | unit | Comportamento de commands + transições de estado 1:1 com os ACs do spec; caminhos de erro/edge repassados aos diálogos | `tests/McGui.App.Tests/**/*.cs` | `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj` |
| `McGui.App` - Views/XAML (camada visual) | none | Verificação manual via skill `run` no macOS (sem e2e automatizado nesta feature) | `src/McGui.App/Views/**/*.axaml` | build gate only + passe manual |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Após tasks com apenas testes unitários | `dotnet test tests/<Projeto>.Tests/<Projeto>.Tests.csproj` (projeto específico da task) |
| Full | Após tasks com testes de integração ou que tocam múltiplos projetos | `dotnet test McGui.sln` |
| Build | Ao final de cada fase, ou tasks somente de config/entidade | `dotnet build McGui.sln -warnaserror && dotnet format McGui.sln --verify-no-changes && dotnet test McGui.sln` |

---

## Execution Plan

Fases ordenadas, execução sequencial - cada fase termina antes da próxima começar, tasks dentro de uma fase rodam em ordem.

### Phase 1: Foundation

```
T1 → T2 → T3
```

### Phase 2: Core - modelos e lógica de domínio

```
T1 -> T4
T4 -> T5
T4 -> T6
T5 -> T7
```

### Phase 3: Infrastructure.macOS

```
T5 -> T8
T5 -> T9
T5 -> T10
```

### Phase 4: App - bootstrap e ViewModels de navegação/seleção

```
T8 -> T11
T9 -> T11
T10 -> T11
T11 -> T12
T12 -> T13
T6 -> T13
T13 -> T14
```

### Phase 5: App - Views e diálogos

```
T14 -> T15
T15 -> T16
T8 -> T16
T15 -> T17
T9 -> T17
T15 -> T18
T8 -> T18
T16 -> T19
```

### Phase 6: Edge cases e validação final

```
T16 -> T20
T17 -> T20
T18 -> T20
T20 -> T21
```

> Dentro de cada fase, mesmo tasks sem dependência direta entre si (ex.: T8/T9/T10, todas dependendo apenas de T5) executam em ordem sequencial - é uma regra de processo da fase de Execute, não uma dependência de dados.

---

## Task Breakdown

### T1: Criar solução .NET e os 3 projetos principais

**What**: Criar `McGui.sln` e os projetos `src/McGui.Core` (biblioteca de classes, sem dependências), `src/McGui.Infrastructure.macOS` (biblioteca de classes, `net8.0`, referência a `McGui.Core`), `src/McGui.App` (projeto Avalonia, referências a `McGui.Core` e `McGui.Infrastructure.macOS`), todos adicionados à solução.
**Where**: `McGui.sln`, `src/McGui.Core/McGui.Core.csproj`, `src/McGui.Infrastructure.macOS/McGui.Infrastructure.macOS.csproj`, `src/McGui.App/McGui.App.csproj`
**Depends on**: None
**Reuses**: N/A (primeira task do repositório)
**Requirement**: Foundational (AD-001)

**Tools**:
- MCP: Context7 (consultar template/CLI atual do Avalonia caso necessário)
- Skill: NONE

**Done when**:
- [x] `dotnet build McGui.sln` compila sem erros com os 3 projetos e as referências corretas (App→Core, App→Infrastructure.macOS, Infrastructure.macOS→Core)
- [x] `McGui.App` roda com uma janela Avalonia vazia (template padrão) sem crash

**Tests**: none
**Gate**: build

**Status**: ✅ Complete
> SPEC_DEVIATION: TFM `net10.0` em vez do `net8.0` sugerido em "Where"/tarefa. Reason: o ambiente de execução só tem o SDK/runtime .NET 10.0.400 instalado (sem runtime net8.0), então um app Avalonia em net8.0 falharia em `dotnet run` (roll-forward não cruza major version por padrão). net10.0 mantém build e execução consistentes no ambiente real. Solução gerada em formato clássico `.sln` (`dotnet new sln --format sln`), já que o SDK .NET 10 tem `.slnx` como padrão e as tasks/gates seguintes referenciam `McGui.sln` explicitamente.

---

### T2: Criar os 3 projetos de teste xUnit

**What**: Criar `tests/McGui.Core.Tests`, `tests/McGui.Infrastructure.macOS.Tests`, `tests/McGui.App.Tests` (xUnit), cada um referenciando seu projeto correspondente em `src/`, e adicioná-los à solução.
**Where**: `tests/McGui.Core.Tests/McGui.Core.Tests.csproj`, `tests/McGui.Infrastructure.macOS.Tests/McGui.Infrastructure.macOS.Tests.csproj`, `tests/McGui.App.Tests/McGui.App.Tests.csproj`
**Depends on**: T1
**Reuses**: Estrutura de projetos de T1
**Requirement**: Foundational

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `dotnet test McGui.sln` executa os 3 projetos de teste (0 testes ainda, sem falha)

**Tests**: none
**Gate**: build

**Status**: ✅ Complete

---

### T3: Configurar `.editorconfig` e gate de formatação/lint

**What**: Adicionar `.editorconfig` na raiz com convenções C#/.NET e confirmar que `dotnet format McGui.sln --verify-no-changes` roda limpo sobre o estado atual do repositório.
**Where**: `.editorconfig`
**Depends on**: T2
**Reuses**: N/A
**Requirement**: Foundational

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `dotnet format McGui.sln --verify-no-changes` retorna sem alterações pendentes
- [x] Gate de Build completo (`dotnet build ... && dotnet format ... && dotnet test ...`) passa

**Tests**: none
**Gate**: build

**Status**: ✅ Complete
> SPEC_DEVIATION: aplicado `dotnet format McGui.sln` (sem `--verify-no-changes`) uma vez para corrigir os arquivos gerados pelo template Avalonia (fim de linha, newline final, ordenação de usings) que já violavam o `.editorconfig` novo. Reason: T3 exige o gate de formatação limpo; sem essa correção pontual o `--verify-no-changes` falharia permanentemente nos arquivos de template do T1.

---

### T4: Definir modelos de dados em `McGui.Core`

**What**: Implementar os records/enums `FileEntry`, `PanelState`, `PanelSortColumn`, `OperationMode`, `CopyMovePlan`, `OperationProgress`, `OperationResult`, `PanelPathHistory` conforme `design.md` (seção Data Models).
**Where**: `src/McGui.Core/Models/*.cs`
**Depends on**: T1
**Reuses**: N/A
**Requirement**: Foundational (sustenta todos os DPC-*)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Todos os tipos listados no design existem com as propriedades especificadas
- [x] `dotnet build McGui.sln` compila sem erros

**Tests**: none
**Gate**: build

**Status**: ✅ Complete

---

### T5: Definir contratos `IFileSystemService`, `ITrashService`, `IPathHistoryStore`

**What**: Implementar as interfaces em `McGui.Core` com as assinaturas descritas em `design.md` (seção Components - `McGui.Core`).
**Where**: `src/McGui.Core/Interfaces/IFileSystemService.cs`, `ITrashService.cs`, `IPathHistoryStore.cs`
**Depends on**: T4
**Reuses**: Modelos de T4
**Requirement**: Foundational (sustenta todos os DPC-*)

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] As 3 interfaces existem com as assinaturas do design, usando os tipos de T4
- [x] `dotnet build McGui.sln` compila sem erros

**Tests**: none
**Gate**: build

**Status**: ✅ Complete

---

### T6: Implementar `SelectionService` (seleção múltipla)

**What**: Implementar `SelectionService` com `Toggle`, `MarkByPattern`, `UnmarkByPattern`, `Invert` operando sobre `PanelState.MarkedPaths`, conforme DPC-09 a DPC-13.
**Where**: `src/McGui.Core/Services/SelectionService.cs`
**Depends on**: T4
**Reuses**: `PanelState`, `FileEntry` de T4
**Requirement**: DPC-09, DPC-10, DPC-11, DPC-12, DPC-13

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Toggle marca/desmarca uma entrada e avança o cursor (DPC-09)
- [x] MarkByPattern/UnmarkByPattern aplicam glob sobre os nomes do painel (DPC-10, DPC-11)
- [x] Invert inverte o estado de marcação de todas as entradas (DPC-12)
- [x] Contagem/tamanho total de marcados é calculável a partir do estado resultante (DPC-13)
- [x] Gate check passa: `dotnet test tests/McGui.Core.Tests/McGui.Core.Tests.csproj`
- [x] Contagem de testes: 5+ testes passando (um por AC DPC-09..13, incluindo padrão sem match) — 8 passaram

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete
> Spec-precision gap: spec.md não define sensibilidade a maiúsculas/minúsculas para os padrões glob de `+`/`-` (DPC-10/11) — ao contrário do filtro case-insensitive de DPC-33. Implementado como case-sensitive (default mais simples); revisar com o usuário se o comportamento esperado for outro.

---

### T7: Implementar `CopyMovePlanner`

**What**: Implementar `CopyMovePlanner.Build(sources, destinationDir, mode, otherPanelCurrentDir)` que expande diretórios recursivamente via `IFileSystemService` (injetado, testável com um fake em memória), detecta cópia/move circular (destino dentro da origem) e bloqueia mover a entrada que é o diretório atual do painel oposto, conforme DPC-18, DPC-22, DPC-23.
**Where**: `src/McGui.Core/Services/CopyMovePlanner.cs`
**Depends on**: T5
**Reuses**: `IFileSystemService` (T5), modelos de T4
**Requirement**: DPC-18, DPC-22, DPC-23

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Destino igual à origem ou subdiretório dela é rejeitado com erro identificando o ciclo (DPC-18)
- [x] Mover uma pasta para dentro dela mesma/subdiretório é rejeitado (DPC-22)
- [x] Mover a entrada que é o diretório atual do painel oposto é bloqueado com explicação (DPC-23)
- [x] Caso feliz (sem conflito) produz um `CopyMovePlan` com todas as entradas expandidas recursivamente
- [x] Gate check passa: `dotnet test tests/McGui.Core.Tests/McGui.Core.Tests.csproj`
- [x] Contagem de testes: 5+ testes passando (feliz + 3 rejeições + expansão recursiva) — 13 passaram no total do projeto (5 novos)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete
> SPEC_DEVIATION: `Build` recebe um 4º parâmetro `otherPanelCurrentDir` (nullable) não listado na assinatura de design.md, necessário para DPC-23; seguido o texto mais concreto/posterior desta task (T7). Rejeições (DPC-18/22/23) lançam `CopyMovePlanValidationException` com mensagem explicativa, já que `CopyMovePlan` (design.md) não tem campo de erro.

---

### T8: Implementar `MacFileSystemService`

**What**: Implementar `IFileSystemService` em `McGui.Infrastructure.macOS` usando `System.IO`/`DriveInfo`: `ListDirectory`, `CreateDirectory`, `CopyAsync`, `MoveAsync` com relatório de progresso, checagem de espaço livre antes de iniciar, política Overwrite/Skip/Rename/Abort por entrada, e skip+relatório em erro de permissão ou falha de escrita a meio da cópia (ver Error Handling Strategy do design). Cobre DPC-01 (listagem), DPC-14 a DPC-21, DPC-24 a DPC-26.
**Where**: `src/McGui.Infrastructure.macOS/MacFileSystemService.cs`
**Depends on**: T5
**Reuses**: Contratos de T5, modelos de T4
**Requirement**: DPC-01, DPC-14, DPC-15, DPC-16, DPC-17, DPC-19, DPC-20, DPC-21, DPC-24, DPC-25, DPC-26

**Tools**:
- MCP: Context7 (verificar comportamento atual de `System.IO`/`DriveInfo` no .NET vigente)
- Skill: NONE

**Done when**:
- [x] `ListDirectory` retorna `FileEntry` corretos para um diretório temporário de teste (nome, tamanho, símlink, oculto)
- [x] `CreateDirectory` cria pasta e rejeita nome duplicado/caractere inválido com erro inline (DPC-24, DPC-25, DPC-26)
- [x] `CopyAsync` copia recursivamente, reporta progresso, respeita cancelamento sem rollback (DPC-15, DPC-17), aplica Overwrite/Skip/Rename/Abort com "aplicar a todos" (DPC-16), aborta antes de iniciar se não houver espaço (DPC-19)
- [x] `MoveAsync` reutiliza as mesmas regras de conflito/espaço de `CopyAsync` (DPC-20) e faz rename in-place quando aplicável (DPC-21)
- [x] Falha de permissão ou de escrita a meio da operação pula o item, continua os demais, e é reportada no `OperationResult` (ver Error Handling Strategy)
- [x] Gate check passa: `dotnet test tests/McGui.Infrastructure.macOS.Tests/McGui.Infrastructure.macOS.Tests.csproj`
- [x] Contagem de testes: 10+ testes passando (um por comportamento acima, usando diretórios temporários reais) — 18 passaram

**Tests**: integration
**Gate**: full

**Status**: ✅ Complete
> SPEC_DEVIATION: `IFileSystemService.CopyAsync`/`MoveAsync` (T5) ganharam um novo parâmetro `Func<string, FileConflictResolution> resolveConflict` (com `FileConflictResolution` novo em `McGui.Core.Models`), ausente na assinatura original de design.md/T5. Reason: sem esse callback não havia como o serviço aplicar Overwrite/Skip/Rename/Abort por conflito (DPC-16), exigido pelo "Done when" desta task; a decisão "aplicar a todos" fica a cargo de quem fornece o delegate (T16, futuro), que pode simplesmente devolver sempre a mesma resolução. `FakeFileSystemService` (T7) foi ajustado mecanicamente para a nova assinatura.
> SPEC_DEVIATION: falha de espaço insuficiente (DPC-19) é sinalizada via nova exceção `InsufficientDiskSpaceException(requiredBytes, availableBytes)` (`McGui.Infrastructure.macOS`), já que `OperationResult` (design.md) não tem campo para os bytes necessários/disponíveis — mesmo padrão de `CopyMovePlanValidationException` (T7). Checagem de espaço é injetável via `Func<string,long>` no construtor de `MacFileSystemService`, necessário para tornar DPC-19 testável sem depender do disco real ter pouco espaço livre.
> Spec-precision gap: "Rename" na resolução de conflito gera automaticamente um nome não colidente no padrão Finder (`arquivo 2.txt`) em vez de pedir um nome ao usuário — a UI de texto livre por conflito é escopo de T16 (futuro), fora desta task de infraestrutura.
> Spec-precision gap: `OperationResult.Succeeded` não tem semântica definida em spec.md para cancelamento vs. Abort explícito. Implementado como `Succeeded=true` para cancelamento via `CancellationToken` (parada graciosa, sem erro) e `Succeeded=false` para "Abort" explícito no diálogo de conflito (operação encerrada por decisão explícita). Revisar com o usuário se a semântica esperada for outra.
> Spec-precision gap: colisão diretório-com-diretório no destino do Copy é tratada como merge silencioso (`Directory.CreateDirectory` idempotente), sem disparar o diálogo de conflito — spec.md não cobre esse caso explicitamente; segue convenção usual de Finder/`cp -r`.
> Nota de ambiente: a validação manual de UI mencionada nas outras tasks não se aplica a T8 (sem Tools/Skill `run` listado); toda a cobertura desta task é via testes de integração com diretórios temporários reais (18 testes).

---

### T9: Implementar `MacTrashService`

**What**: Implementar `ITrashService.Delete` movendo entradas para `~/.Trash` (ou `.Trashes/<uid>` em outro volume) com renomeação segura em colisão de nome, exclusão permanente quando solicitado (`permanent: true`) ou quando não há lixeira disponível, e retorno de erro tratável (nunca exclusão silenciosa) quando o destino de lixeira não puder ser escrito. Cobre DPC-27 a DPC-31.
**Where**: `src/McGui.Infrastructure.macOS/MacTrashService.cs`
**Depends on**: T5
**Reuses**: Contratos de T5, modelos de T4
**Requirement**: DPC-27, DPC-28, DPC-29, DPC-30, DPC-31

**Tools**:
- MCP: Context7 (confirmar convenções de `~/.Trash`/`.Trashes` antes de implementar - risco já sinalizado no design)
- Skill: `run` (validar manualmente em macOS real que o item aparece na lixeira do Finder)

**Done when**:
- [x] Exclusão normal move o item para `~/.Trash`, renomeando em colisão (`arquivo.txt` → `arquivo 2.txt`) (DPC-28)
- [x] Exclusão com `permanent: true` apaga de vez, sem passar pela lixeira (DPC-30)
- [x] Ausência de lixeira no destino resulta em exclusão permanente (DPC-29)
- [x] Erro de permissão ao escrever na lixeira retorna `OperationResult` com falha explicada, sem apagar nada (Error Handling Strategy)
- [x] Falha de permissão ao apagar um item específico é reportada e não interrompe os demais itens do lote (DPC-31)
- [ ] Validação manual: em macOS real, um arquivo apagado aparece na lixeira do Finder e pode ser restaurado
- [x] Gate check passa: `dotnet test tests/McGui.Infrastructure.macOS.Tests/McGui.Infrastructure.macOS.Tests.csproj`
- [x] Contagem de testes: 6+ testes passando — 7 passaram (25 no total do projeto)

**Tests**: integration
**Gate**: full

**Status**: ✅ Complete
> SPEC_DEVIATION: `MacTrashService` recebe `homeDirectory` e `trashRootForPath` opcionais no construtor (não mencionados em design.md) para permitir testar sem tocar na lixeira real do usuário, conforme pedido explícito do batch. `trashRootForPath` retornando `null` modela "sem lixeira disponível" (DPC-29, fallback para exclusão permanente); um resolver não-nulo cujo diretório não pode ser criado/escrito modela a falha de escrita coberta pela Error Handling Strategy (relata erro, não apaga nada) — spec.md não distingue essas duas situações explicitamente, tratado como spec-precision gap.
> Spec-precision gap: detecção de "mesmo volume que o home" usa `VolumeLocator` (T8) comparando `DriveInfo.RootDirectory`; `.Trashes/<uid>` usa `getuid()` via P/Invoke a `libc` (sem dependência de terceiros, conforme Tech Decision de design.md). Não foi possível testar esse ramo de "outro volume" com um volume físico real neste ambiente — coberto indiretamente injetando `trashRootForPath` customizado, que exercita a mesma lógica de colisão/movimentação independente da raiz escolhida.
> Nota de ambiente: a validação manual via skill `run` (Finder mostrando o item na lixeira) não pôde ser executada nesta sessão não-interativa (sem acesso a GUI); marcado como pendente no Done-when. Cobertura automatizada substitui via diretórios temporários reais que exercitam a mesma lógica de movimentação/renomeação usada para `~/.Trash`.

---

### T10: Implementar `MacPathHistoryStore`

**What**: Implementar `IPathHistoryStore.Load/Save` persistindo `PanelPathHistory` como JSON em `~/Library/Application Support/mc-gui/state.json`, com fallback para diretório home quando o arquivo não existe ou aponta para um caminho inexistente. Cobre DPC-07, DPC-08.
**Where**: `src/McGui.Infrastructure.macOS/MacPathHistoryStore.cs`
**Depends on**: T5
**Reuses**: Contratos de T5, modelos de T4
**Requirement**: DPC-07, DPC-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] `Save` grava os dois caminhos em JSON no caminho esperado (parametrizável para diretório temporário nos testes)
- [x] `Load` restaura os caminhos salvos (DPC-07)
- [x] `Load` cai para o diretório home quando o arquivo não existe ou aponta para um caminho inexistente (DPC-08)
- [x] Gate check passa: `dotnet test tests/McGui.Infrastructure.macOS.Tests/McGui.Infrastructure.macOS.Tests.csproj`
- [x] Contagem de testes: 4+ testes passando — 5 passaram (30 no total do projeto)

**Tests**: integration
**Gate**: full

**Status**: ✅ Complete
> Spec-precision gap: DPC-08 é aplicado por painel individualmente (cada caminho persistido é validado de forma independente), não como fallback "tudo ou nada" para o par — spec.md não deixa explícito se um painel válido deve cair para home quando o outro está inválido; tratado como comportamento mais útil e coberto por teste dedicado (`Load_PersistedPathNoLongerExists_FallsBackToHomeForThatPanelOnly`).
> JSON corrompido/ilegível no arquivo de estado também cai para o fallback de home em ambos os painéis (mesma tratativa de "arquivo não existe" da DPC-08), já que spec.md não distingue os dois casos.

---

### T11: Bootstrap do app Avalonia e injeção de dependência

**What**: Configurar `App.axaml.cs`/`Program.cs` com um container de DI simples (`Microsoft.Extensions.DependencyInjection`) registrando as implementações de `McGui.Infrastructure.macOS` contra os contratos de `McGui.Core`, resolvendo `MainWindowViewModel` na inicialização.
**Where**: `src/McGui.App/App.axaml.cs`, `src/McGui.App/Program.cs`
**Depends on**: T8, T9, T10
**Reuses**: Serviços de T8, T9, T10; contratos de T5
**Requirement**: Foundational

**Tools**:
- MCP: Context7 (padrão atual de bootstrap/DI recomendado pelo Avalonia)
- Skill: `run` (validar que o app abre sem crash)

**Done when**:
- [x] Container resolve todos os serviços registrados sem exceção
- [ ] App abre uma janela (ainda vazia de UI de painéis) sem crash no macOS
- [x] Gate check passa: `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj`
- [x] Contagem de testes: 1+ teste passando (resolução do container)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete
> SPEC_DEVIATION: criado `src/McGui.App/ViewModels/MainWindowViewModel.cs` (classe vazia, apenas resolvível via DI) nesta task, embora o campo "Where" de T11 não o liste — necessário porque "Done when" exige resolver `MainWindowViewModel` pelo container antes de T13 (que depende de T11) existir para preenchê-la com painéis/Tab. T13 estende esta classe. `Program.cs` não precisou de alteração: o bootstrap de DI foi feito em `App.axaml.cs.OnFrameworkInitializationCompleted`, ponto padrão do Avalonia para compor o `MainWindow`/DataContext antes de exibir a janela.
> Nota de ambiente: `dotnet run` nesta sessão (shell não-interativo, sem sessão de window server ativa) falha em `Avalonia.Native.AvaloniaNativeRenderTimer.EnsureRegistered()` ("was not able to start the RenderTimer") antes mesmo de `OnFrameworkInitializationCompleted` ser chamado — é uma limitação do ambiente de execução deste agente (mesma classe de limitação já registrada em T9 para a skill `run`), não uma regressão introduzida por este código. A verificação "app abre janela sem crash" fica pendente de validação manual em uma sessão macOS interativa real.

---

### T12: `PanelViewModel` - navegação

**What**: Implementar `PanelViewModel` com navegação (mudar diretório, subir para pai, mover cursor, indicador de carregamento acima de 500ms) e persistência do diretório atual via `IPathHistoryStore` ao fechar/abrir o app. Cobre DPC-01 a DPC-05, DPC-07, DPC-08.
**Where**: `src/McGui.App/ViewModels/PanelViewModel.cs`
**Depends on**: T11
**Reuses**: `IFileSystemService`, `IPathHistoryStore` (via DI de T11)
**Requirement**: DPC-01, DPC-02, DPC-03, DPC-04, DPC-05, DPC-07, DPC-08

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Estado inicial lista o diretório persistido ou o home do usuário como fallback (DPC-01, DPC-08)
- [x] Navegar para subdiretório e para o pai atualiza `CurrentDirectory`/`Entries` (DPC-04, DPC-05)
- [x] Mover cursor para cima/baixo respeita os limites (não dá wrap) (DPC-03)
- [x] Indicador de carregamento fica ativo quando a listagem simulada demora mais que 500ms (DPC-06, com fake `IFileSystemService` controlando o delay)
- [x] Fechar persiste o diretório atual via `IPathHistoryStore.Save` (DPC-07)
- [x] Gate check passa: `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj`
- [x] Contagem de testes: 8+ testes passando — 10 novos (11 no total do projeto)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete
> Spec-precision gap: o limiar de 500ms de DPC-06 é injetável via `loadingIndicatorDelay` no construtor (padrão 500ms em produção) para permitir testes determinísticos e rápidos sem `Thread.Sleep(500)` real; o comportamento (indicador só aparece após o limiar, nunca antes) é o mesmo exigido pelo AC.
> Spec-precision gap: DPC-08 no nível de ViewModel valida o caminho persistido tentando `IFileSystemService.ListDirectory` (capturando `IOException`/`UnauthorizedAccessException`, incluindo `DirectoryNotFoundException`) em vez de checar existência diretamente — mantém toda a E/S atrás da abstração já usada pelo ViewModel (nenhuma chamada direta a `System.IO` em `McGui.App`), reforçando a fronteira de plataforma do AD-001. Navegação explícita (Enter/Backspace) para um diretório que falhar nessa mesma checagem apenas mantém o estado atual sem navegar; o tratamento de erro inline completo é escopo de T20.
> Nota: `NavigateToAsync(string)` e `PersistCurrentDirectory()` não são `[RelayCommand]` porque não aparecem como gestos diretos em `KeyGestureMap` (T14) — `NavigateToAsync` é usado por double-click/Enter via `ActivateCursorEntryCommand`, e `PersistCurrentDirectory` é chamado pelo host da aplicação ao fechar (fora do escopo de teclado).

---

### T13: `PanelViewModel` - seleção múltipla e troca de painel ativo

**What**: Conectar `PanelViewModel` ao `SelectionService` (T6) para Toggle/MarkByPattern/UnmarkByPattern/Invert, e implementar em `MainWindowViewModel` a troca de painel ativo via Tab (destaque visual do painel focado). Cobre DPC-02, DPC-09 a DPC-13.
**Where**: `src/McGui.App/ViewModels/PanelViewModel.cs` (extensão), `src/McGui.App/ViewModels/MainWindowViewModel.cs`
**Depends on**: T12, T6
**Reuses**: `SelectionService` de T6
**Requirement**: DPC-02, DPC-09, DPC-10, DPC-11, DPC-12, DPC-13

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Comandos de marcar/desmarcar/padrão/inverter delegam para `SelectionService` e atualizam a UI-bound `PanelState` (DPC-09..12)
- [x] Status line expõe contagem/tamanho de marcados reativamente (DPC-13)
- [x] `MainWindowViewModel` alterna qual painel está ativo ao comando de Tab (DPC-02)
- [x] Gate check passa: `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj`
- [x] Contagem de testes: 6+ testes passando — 7 novos (18 no total do projeto)

**Tests**: unit
**Gate**: quick

**Status**: ✅ Complete
> Spec-precision gap: `MarkedSizeBytes` é calculado por projeção sobre `_state.Entries` filtrando por `MarkedPaths` (em vez de um campo persistido em `PanelState`) para evitar duplicar a soma toda vez que `MarkedPaths` muda — ela é recomputada sob demanda e republicada via `NotifySelectionChanged` após cada comando, mantendo `PanelState` (Core) livre de lógica de apresentação.
> Nota: `ToggleMark`, `MarkByPattern`, `UnmarkByPattern` e `InvertMarks` são `[RelayCommand]` pois aparecem como gestos diretos (Insert/Space, `+`, `-`, `*`) no `KeyGestureMap` de T14; `SwitchActivePanel` em `MainWindowViewModel` também é `[RelayCommand]` pelo mesmo motivo (gesto Tab).

---

### T14: `KeyGestureMap` (atalhos clássicos do MC)

**What**: Implementar a tabela estática de atalhos (F1-F10, Tab, Insert, `+`, `-`, `*`, Ctrl+R, Ctrl+H, Backspace) mapeando cada tecla ao Command correspondente nas ViewModels já implementadas, com F3/F4 mapeados para um estado "desabilitado" (assumption do spec).
**Where**: `src/McGui.App/Input/KeyGestureMap.cs`
**Depends on**: T13
**Reuses**: Commands de `PanelViewModel`/`MainWindowViewModel`
**Requirement**: DPC-02 (Tab), DPC-09..12 (Insert/+/-/*), Foundational para F5-F8 (wiring final feito em T16-T18)

**Tools**:
- MCP: Context7 (confirmar captura de F-keys em janela Avalonia no macOS - risco sinalizado no design)
- Skill: NONE

**Done when**:
- [ ] Todas as teclas listadas no design têm uma entrada no mapa, incluindo F3/F4 como desabilitadas
- [ ] Teste confirma que o mapa cobre 100% das teclas exigidas pelo spec (nenhuma faltando)
- [ ] Gate check passa: `dotnet test tests/McGui.App.Tests/McGui.App.Tests.csproj`
- [ ] Contagem de testes: 2+ testes passando (cobertura do mapa + F3/F4 desabilitadas)

**Tests**: unit
**Gate**: quick

---

### T15: Views - `MainWindow`/`PanelView` e barra de function-keys

**What**: Implementar `MainWindow.axaml`/`PanelView.axaml` renderizando os dois painéis lado a lado, destaque do painel ativo, indicador de carregamento, e a barra de 10 F-keys (F3/F4 visualmente desabilitados), ligados às ViewModels de T12-T14.
**Where**: `src/McGui.App/Views/MainWindow.axaml`, `src/McGui.App/Views/PanelView.axaml`
**Depends on**: T14
**Reuses**: ViewModels de T12, T13; `KeyGestureMap` de T14
**Requirement**: DPC-01, DPC-02, DPC-03, DPC-06

**Tools**:
- MCP: Context7 (data binding/controles atuais do Avalonia)
- Skill: `run` (validar visualmente os dois painéis, destaque de foco, barra de F-keys)

**Done when**:
- [ ] App abre mostrando dois painéis com listagem real do diretório home (verificado com `run`)
- [ ] Tab alterna o destaque visual entre os painéis (DPC-02)
- [ ] Barra de F-keys visível com F3/F4 desabilitados
- [ ] Gate check passa: `dotnet build McGui.sln -warnaserror`

**Tests**: none
**Gate**: build

---

### T16: Diálogo de Copiar/Mover (F5/F6) + integração end-to-end

**What**: Implementar `CopyMoveDialogViewModel`/View (destino editável, pré-preenchido com o painel oposto) e `ConflictDialogViewModel`/View (Overwrite/Skip/Rename/Abort + "aplicar a todos"), ligando F5/F6 do `KeyGestureMap` ao `CopyMovePlanner` (T7) e ao `MacFileSystemService` (T8) via progresso e cancelamento. Cobre DPC-14 a DPC-23.
**Where**: `src/McGui.App/ViewModels/CopyMoveDialogViewModel.cs`, `src/McGui.App/ViewModels/ConflictDialogViewModel.cs`, `src/McGui.App/Views/CopyMoveDialog.axaml`, `src/McGui.App/Views/ConflictDialog.axaml`
**Depends on**: T8, T15
**Reuses**: `CopyMovePlanner` (T7), `MacFileSystemService` (T8)
**Requirement**: DPC-14, DPC-15, DPC-16, DPC-17, DPC-18, DPC-19, DPC-20, DPC-21, DPC-22, DPC-23

**Tools**:
- MCP: Context7 (padrão de diálogos modais no Avalonia)
- Skill: `run` (validar visualmente copiar/mover/cancelar/conflito de nome em arquivos reais)

**Done when**:
- [ ] F5 abre o diálogo pré-preenchido com o destino do painel oposto e confirma cópia real, recursiva, com progresso (DPC-14, DPC-15)
- [ ] F6 move ou renomeia in-place conforme a regra de T7 (DPC-20, DPC-21)
- [ ] Conflito de nome real dispara `ConflictDialog` com as 4 opções + "aplicar a todos" (DPC-16)
- [ ] Cancelar durante a cópia interrompe sem rollback (DPC-17)
- [ ] Cópia/move circular e mover-diretório-atual-do-painel-oposto são bloqueados com mensagem visível (DPC-18, DPC-22, DPC-23)
- [ ] Espaço insuficiente aborta antes de iniciar com mensagem de bytes (DPC-19)
- [ ] Gate check passa: `dotnet test McGui.sln`
- [ ] Contagem de testes: 8+ testes (ViewModel) + validação manual via `run`

**Tests**: integration
**Gate**: full

---

### T17: Diálogo de Apagar (F8)

**What**: Implementar `DeleteConfirmDialogViewModel`/View mostrando contagem/tamanho, ligando F8 ao `MacTrashService` (T9), com o fluxo Shift-para-permanente e mensagem de irreversibilidade. Cobre DPC-27 a DPC-31.
**Where**: `src/McGui.App/ViewModels/DeleteConfirmDialogViewModel.cs`, `src/McGui.App/Views/DeleteConfirmDialog.axaml`
**Depends on**: T9, T15
**Reuses**: `MacTrashService` (T9)
**Requirement**: DPC-27, DPC-28, DPC-29, DPC-30, DPC-31

**Tools**:
- MCP: NONE
- Skill: `run` (validar visualmente apagar-para-lixeira e Shift+apagar permanente em arquivos reais)

**Done when**:
- [ ] F8 mostra contagem/tamanho antes de confirmar (DPC-27)
- [ ] Confirmação normal move para a lixeira real do macOS, verificado manualmente (DPC-28)
- [ ] Shift+confirmar apaga permanentemente com aviso de irreversibilidade visível (DPC-30)
- [ ] Item com erro de permissão é pulado e reportado ao final, sem interromper os demais (DPC-31)
- [ ] Gate check passa: `dotnet test McGui.sln`
- [ ] Contagem de testes: 5+ testes (ViewModel) + validação manual via `run`

**Tests**: integration
**Gate**: full

---

### T18: Diálogo de Criar Diretório (F7)

**What**: Implementar `MkdirDialogViewModel`/View pedindo o nome da nova pasta, ligando F7 ao `MacFileSystemService.CreateDirectory` (T8), com erro inline para nome duplicado ou caractere inválido. Cobre DPC-24 a DPC-26.
**Where**: `src/McGui.App/ViewModels/MkdirDialogViewModel.cs`, `src/McGui.App/Views/MkdirDialog.axaml`
**Depends on**: T8, T15
**Reuses**: `MacFileSystemService` (T8)
**Requirement**: DPC-24, DPC-25, DPC-26

**Tools**:
- MCP: NONE
- Skill: `run` (validar visualmente criação de pasta e as duas mensagens de erro)

**Done when**:
- [ ] F7 cria a pasta real no diretório ativo ao confirmar (DPC-24)
- [ ] Nome duplicado mostra erro inline sem fechar o diálogo (DPC-25)
- [ ] Caractere inválido para o SO mostra erro inline identificando o caractere (DPC-26)
- [ ] Gate check passa: `dotnet test McGui.sln`
- [ ] Contagem de testes: 4+ testes (ViewModel) + validação manual via `run`

**Tests**: integration
**Gate**: full

---

### T19: Diálogo de Progresso e cancelamento

**What**: Implementar `ProgressDialogViewModel`/View exibindo percentual, arquivo atual e botão Cancelar, consumido por `CopyMoveDialogViewModel` (T16) via `IProgress<OperationProgress>`. Cobre DPC-15, DPC-17 (parte visual).
**Where**: `src/McGui.App/ViewModels/ProgressDialogViewModel.cs`, `src/McGui.App/Views/ProgressDialog.axaml`
**Depends on**: T16
**Reuses**: `OperationProgress` (T4), fluxo de T16
**Requirement**: DPC-15, DPC-17

**Tools**:
- MCP: NONE
- Skill: `run` (validar visualmente barra de progresso e cancelamento em uma cópia de arquivos grandes reais)

**Done when**:
- [ ] Percentual e nome do arquivo atual atualizam durante uma cópia real de múltiplos arquivos (DPC-15)
- [ ] Botão Cancelar interrompe após o arquivo atual, mantendo os já copiados (DPC-17)
- [ ] Gate check passa: `dotnet test McGui.sln`
- [ ] Contagem de testes: 3+ testes (ViewModel) + validação manual via `run`

**Tests**: integration
**Gate**: full

---

### T20: Edge cases do spec

**What**: Implementar os edge cases listados no spec ainda não cobertos: operação com zero entradas não abre diálogo; painel cujo diretório fica inacessível mostra erro inline com ação "ir para home"; diálogo de destino inexistente oferece criar o diretório como parte da confirmação.
**Where**: `src/McGui.App/ViewModels/PanelViewModel.cs`, `src/McGui.App/ViewModels/CopyMoveDialogViewModel.cs` (extensões)
**Depends on**: T16, T17, T18
**Reuses**: ViewModels existentes
**Requirement**: Edge Cases (spec.md)

**Tools**:
- MCP: NONE
- Skill: `run` (validar manualmente desmontar/renomear um diretório aberto no painel)

**Done when**:
- [ ] F5/F6/F8 com zero entradas selecionadas e sem cursor válido não abrem diálogo algum
- [ ] Painel cujo diretório desaparece mostra estado de erro inline com ação "ir para home", testável simulando remoção do diretório corrente
- [ ] Diálogo de destino inexistente oferece criar o diretório ao confirmar, em vez de falhar
- [ ] Gate check passa: `dotnet test McGui.sln`
- [ ] Contagem de testes: 3+ testes

**Tests**: unit
**Gate**: full

---

### T21: Validação manual completa do MVP em macOS

**What**: Rodar o app completo via skill `run` e percorrer manualmente o ciclo navegar → marcar → copiar/mover/renomear/apagar (lixeira e permanente) → criar pasta em ambos os painéis, conferindo cada Success Criteria do spec.
**Where**: N/A (validação, sem novo código de produção)
**Depends on**: T20 (última task; todas as demais são pré-requisitos transitivos de T20)
**Reuses**: App completo
**Requirement**: Success Criteria (spec.md)

**Tools**:
- MCP: NONE
- Skill: `run` (obrigatório - é a task de validação manual)

**Done when**:
- [ ] Todos os Success Criteria do spec.md são verificados manualmente e passam
- [ ] `dotnet build McGui.sln -warnaserror && dotnet format McGui.sln --verify-no-changes && dotnet test McGui.sln` passa (gate Build completo)
- [ ] Nenhuma regressão encontrada nas P1 stories durante o percurso manual

**Tests**: none
**Gate**: build

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
```

As setas de dependência entre tasks (dentro e entre fases) estão nos diagramas de cada fase, na seção Execution Plan acima - não duplicadas aqui para evitar divergência. Ordem de execução dentro de cada fase (quando não há dependência direta entre tasks da mesma fase, ex.: T8/T9/T10): segue a ordem em que as tasks aparecem no Task Breakdown.

Execução estritamente sequencial - sem paralelismo intra-fase.

**Empacotamento em batches (~7 tasks/worker, fases inteiras):**

| Batch | Fases | Tasks | Total |
| --- | --- | --- | --- |
| A | Phase 1 + Phase 2 | T1-T7 | 7 |
| B | Phase 3 + Phase 4 | T8-T14 | 7 |
| C | Phase 5 + Phase 6 | T15-T21 | 7 |

21 tasks totais → 3 batches de 7. Acima do limite de execução inline (~8), então a oferta de sub-agentes se aplica (ver Sub-Agent Delegation).

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: Solução + 3 projetos | 1 entrega de scaffolding coesa | ✅ Granular |
| T2: 3 projetos de teste | 1 entrega de scaffolding coesa | ✅ Granular |
| T3: `.editorconfig` + gate de formatação | 1 arquivo/config | ✅ Granular |
| T4: Modelos de dados | 1 conjunto coeso de tipos, sem lógica | ✅ Granular |
| T5: Interfaces | 1 conjunto coeso de contratos | ✅ Granular |
| T6: `SelectionService` | 1 classe | ✅ Granular |
| T7: `CopyMovePlanner` | 1 classe | ✅ Granular |
| T8: `MacFileSystemService` | 1 classe (implementa 1 interface) | ✅ Granular |
| T9: `MacTrashService` | 1 classe (implementa 1 interface) | ✅ Granular |
| T10: `MacPathHistoryStore` | 1 classe (implementa 1 interface) | ✅ Granular |
| T11: Bootstrap/DI | 1 entrega coesa (composição raiz) | ✅ Granular |
| T12: `PanelViewModel` - navegação | 1 classe, 1 responsabilidade | ✅ Granular |
| T13: `PanelViewModel` - seleção/foco | Extensão da mesma classe + 1 classe pequena | ✅ Granular |
| T14: `KeyGestureMap` | 1 classe | ✅ Granular |
| T15: Views principais | 2 arquivos XAML fortemente acoplados (janela + painel) | ✅ Granular |
| T16: Diálogo Copiar/Mover | 2 ViewModels + 2 Views de um mesmo fluxo coeso | ✅ Granular |
| T17: Diálogo Apagar | 1 ViewModel + 1 View | ✅ Granular |
| T18: Diálogo Mkdir | 1 ViewModel + 1 View | ✅ Granular |
| T19: Diálogo de Progresso | 1 ViewModel + 1 View | ✅ Granular |
| T20: Edge cases | Extensões pontuais em ViewModels já existentes | ✅ Granular |
| T21: Validação manual | 1 atividade de verificação, sem código novo | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | (início da Phase 1) | ✅ Match |
| T2 | T1 | T1→T2 | ✅ Match |
| T3 | T2 | T2→T3 | ✅ Match |
| T4 | T1 | T1→T4 | ✅ Match |
| T5 | T4 | T4→T5 | ✅ Match |
| T6 | T4 | T4→T6 | ✅ Match |
| T7 | T5 | T5→T7 | ✅ Match |
| T8 | T5 | T5→T8 | ✅ Match |
| T9 | T5 | T5→T9 | ✅ Match |
| T10 | T5 | T5→T10 | ✅ Match |
| T11 | T8, T9, T10 | T8→T11, T9→T11, T10→T11 | ✅ Match |
| T12 | T11 | T11→T12 | ✅ Match |
| T13 | T12, T6 | T12→T13, T6→T13 | ✅ Match |
| T14 | T13 | T13→T14 | ✅ Match |
| T15 | T14 | T14→T15 | ✅ Match |
| T16 | T8, T15 | T8→T16, T15→T16 | ✅ Match |
| T17 | T9, T15 | T9→T17, T15→T17 | ✅ Match |
| T18 | T8, T15 | T8→T18, T15→T18 | ✅ Match |
| T19 | T16 | T16→T19 | ✅ Match |
| T20 | T16, T17, T18 | T16→T20, T17→T20, T18→T20 | ✅ Match |
| T21 | T20 | T20→T21 | ✅ Match |

Nenhuma dependência aponta para uma fase posterior. Todas as setas do diagrama têm `Depends on` correspondente e vice-versa.

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1 | Scaffolding de projeto | none | none | ✅ OK |
| T2 | Scaffolding de teste | none | none | ✅ OK |
| T3 | Config | none | none | ✅ OK |
| T4 | `McGui.Core` modelos | none | none | ✅ OK |
| T5 | `McGui.Core` contratos | none | none | ✅ OK |
| T6 | `McGui.Core` lógica de domínio | unit | unit | ✅ OK |
| T7 | `McGui.Core` lógica de domínio | unit | unit | ✅ OK |
| T8 | `McGui.Infrastructure.macOS` | integration | integration | ✅ OK |
| T9 | `McGui.Infrastructure.macOS` | integration | integration | ✅ OK |
| T10 | `McGui.Infrastructure.macOS` | integration | integration | ✅ OK |
| T11 | `McGui.App` bootstrap (ViewModel-adjacent) | unit | unit | ✅ OK |
| T12 | `McGui.App` ViewModels | unit | unit | ✅ OK |
| T13 | `McGui.App` ViewModels | unit | unit | ✅ OK |
| T14 | `McGui.App` ViewModels/Input | unit | unit | ✅ OK |
| T15 | `McGui.App` Views/XAML | none | none | ✅ OK |
| T16 | `McGui.App` ViewModels + `McGui.Infrastructure.macOS` real (fluxo ponta a ponta) | maior exigência entre as camadas tocadas = integration | integration | ✅ OK |
| T17 | `McGui.App` ViewModels + `McGui.Infrastructure.macOS` real | integration | integration | ✅ OK |
| T18 | `McGui.App` ViewModels + `McGui.Infrastructure.macOS` real | integration | integration | ✅ OK |
| T19 | `McGui.App` ViewModels + `McGui.Infrastructure.macOS` real | integration | integration | ✅ OK |
| T20 | `McGui.App` ViewModels | unit (lógica), mas gate full por tocar fluxo integrado | unit | ✅ OK |
| T21 | Nenhum código de produção novo | none | none | ✅ OK |

Nenhuma violação: nenhuma task usa "testado em outra task" como justificativa para `Tests: none`; todo `none` corresponde a uma camada que a matrix já marca como `none`.
