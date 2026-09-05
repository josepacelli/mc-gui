# macOS Installer Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/macos-installer/design.md`
**Status**: Draft

---

## Test Coverage Matrix

| Layer | Validation | Coverage Expectation | Command |
| --- | --- | --- | --- |
| Script `build-macos.sh` | auto-checks embutidos + UAT | Gera `.app` válido (plist lint ok, binário arm64, icns presente) e DMG; idempotente; versão por arg | `./packaging/build-macos.sh` (+ `0.2.0` variação) |
| `Info.plist` | auto-check | `plutil -lint` exit 0; keys corretas | `plutil -lint artifacts/mc-gui.app/Contents/Info.plist` |
| Ícone | auto-check | `mc-gui.icns` não-vazio; round-trip iconutil | `iconutil -c icns`; `sips` |
| DMG | auto-check + montagem local | `hdiutil create` ok; mount revela app + Applications link | `hdiutil attach` local (task) |
| CI workflow | YAML válido + (se possível) trigger | Gera artifact DMG; release em tag | revisão YAML; UAT CI na execução se ambiente permitir |
| Suíte .NET | regressão | Nenhuma mudança runtime → todos os 180+ testes seguem verdes | `dotnet test McGui.sln` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Build | Tasks de script/plist/ícone | `dotnet build McGui.sln -warnaserror` (regressão) |
| Full | Fim da feature | `./packaging/build-macos.sh && dotnet format McGui.sln --verify-no-changes && dotnet build McGui.sln -warnaserror && dotnet test McGui.sln` |

---

## Execution Plan

```
T1
T1 -> T2
T2 -> T3
T3 -> T4
```

---

## Task Breakdown

### T1: `packaging/` base — Info.plist template + make-icon.sh + gitignore

**What**: Criar `packaging/Info.plist` (template com placeholders p/ versão, keys de D3/design), `packaging/make-icon.sh` (gera PNG 1024 programático via Python PIL → `artifacts/build/icon-source.png` → iconset via `sips` → `artifacts/build/mc-gui.icns` via `iconutil`), e adicionar `artifacts/` ao `.gitignore`. Rodar make-icon isolado p/ validar (gera icns sem erro, não-vazio). Auto-check embutido no script p/ falhar se python3/PIL/sips/iconutil ausentes.
**Where**: `packaging/Info.plist`, `packaging/make-icon.sh`, `.gitignore`
**Depends on**: none
**Reuses**: N/A
**Requirement**: PKG-10, PKG-11

**Done when**:
- [x] `Info.plist` template presente com keys de D3 (id `mcgui.jpmo.dev.br`, name mc-gui, exec mc-gui, versão placeholder, APPL, NSHighResolutionCapable, icns)
- [x] `make-icon.sh` gera PNG 1024 + `.icns` não-vazio; `iconutil` sem erro (108KB icns validado)
- [x] `artifacts/` gitignored (+ *.dmg, *.app/)
- [x] Regressão build ok

**Tests**: auto-checks de script (iconutil/sips)
**Gate**: build

**Status**: ✅ Complete

---

### T2: `packaging/build-macos.sh` gera .app válido

**What**: Criar `build-macos.sh`: limpa `artifacts/`; `dotnet publish -c Release -r osx-arm64 --self-contained true -p:UseAppHost=true -o artifacts/publish`; monta `mc-gui.app/Contents/{MacOS,Resources}`; copia publish→MacOS; renomeia apphost `McGui.App`→`mc-gui`; injeta versão no Info.plist (default 0.1.0 ou `$1`); copia Info.plist e `.icns`. Auto-checks: `plutil -lint`, `file MacOS/mc-gui` contém `arm64` e `executable`, `.icns` presente. 
**Where**: `packaging/build-macos.sh`
**Depends on**: T1
**Reuses**: make-icon.sh
**Requirement**: PKG-01, PKG-03, PKG-04, PKG-05, PKG-06, PKG-07, PKG-08

**Done when**:
- [x] `./packaging/build-macos.sh` gera `artifacts/mc-gui.app` com estrutura e binário arm64
- [x] Idempotente (2ª execução sem erro)
- [x] Auto-checks passam (plutil lint ok, file arm64); versão por arg (0.2.0) ok

**Tests**: auto-checks script
**Gate**: build

**Status**: ✅ Complete

---

### T3: DMG drag-to-install + UAT local de montagem

**What**: Estender `build-macos.sh` p/ preparar dir do volume (app + link/folder Applications) e `hdiutil create` → `artifacts/mc-gui-${VERSION}-arm64.dmg`. UAT local: montar o DMG (`hdiutil attach`), confirmar `mc-gui.app` e Applications; abrir o app do volume (visual), conferir nome/ícone/versão no Finder; desmontar.
**Where**: `packaging/build-macos.sh`
**Depends on**: T2
**Reuses**: N/A
**Requirement**: PKG-02, PKG-09, edge (DMG contém app + Applications)

**Done when**:
- [x] DMG `mc-gui-0.1.0-arm64.dmg` criado e monta com app + link Applications
- [x] App abre do volume (janela mc-gui confirmada); DMG desmonta
- [x] Regressão suíte ok (nenhum código runtime alterado)
- [x] UAT visual do usuário: "Tudo ok"

**Tests**: auto-check hdiutil + UAT
**Gate**: full (parcial: sem xunit; executa build + teste)

**Status**: ✅ Complete

---

### T4: GitHub Actions workflow + fechamento

**What**: Criar `.github/workflows/build-macos.yml`: `macos-14` runner; checkout; setup-dotnet 10.x; chmod scripts; rodar `build-macos.sh` (versão de tag `v*` ou 0.1.0); upload-artifact do `.dmg`; em tag, `gh release upload`. Full gate + registro. Se runner arm64 indisponível, documentar fallback (registrar SPEC_DEVIATION se necessário).
**Where**: `.github/workflows/build-macos.yml`
**Depends on**: T3
**Reuses**: build-macos.sh
**Requirement**: PKG-12, PKG-13, PKG-14

**Done when**:
- [ ] Workflow YAML válido, reusa build-macos.sh
- [ ] Full gate verde local
- [ ] UAT CI: se push possível, confirmar artifact; senão registrar como pendente de trigger remoto

**Tests**: YAML review + gate
**Gate**: full

**Status**: ⬜ Pending

---

## Task Granularity Check

> T1 base (plist+ícone), T2 script .app, T3 DMG+UAT, T4 CI. Cada task atômica; sem testes xunit (empacotamento é validado por auto-checks + UAT); suíte .NET como regressão.

## Diagram-Definition Cross-Check

> Sequência T1→T2→T3→T4; `Depends on` espelha o plano. T2 precisa do ícone/plist (T1); T3 do .app (T2); T4 do script pronto (T3).

## Test Co-location Validation

> Sem novo xunit; validação determinística nos auto-checks dos scripts + UAT manual; regressão pela suíte .NET.
