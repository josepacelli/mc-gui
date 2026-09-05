# macOS Installer Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O `mc-gui` hoje roda apenas via `dotnet run`/publish manual — não há um artefato instalável no macOS. Para distribuir como aplicativo nativo, é preciso empacotar o app Avalonia num bundle `.app` (estrutura `Contents/{MacOS,Resources,Info.plist}`), com ícone `.icns`, e gerar um **DMG drag-to-Applications** (usuário arrasta `mc-gui.app` para `/Applications`). Build sem assinatura (uso dev/próprio; Gatekeeper pede clique-direito+Abrir na primeira execução), arquitetura arm64 (Apple Silicon), versão inicial 0.1.0, bundle id `mcgui.jpmo.dev.br`. Geração por **script local** no repo **e** por **GitHub Actions workflow** (CI gera DMG como artefato a cada push/tag).

## Goals

- [ ] Script `build-macos.sh` gera, a partir do código-fonte, um `.app` válido com `Info.plist` correto + ícone `.icns` e empacota num DMG `mc-gui-0.1.0-arm64.dmg` drag-to-Applications.
- [ ] Workflow GitHub Actions (`build-macos.yml`) produz o mesmo DMG em macOS arm64 runner (e em runner Intel? decisão: runner arm64) e o expõe como artefato/download de release.
- [ ] Bundle abre no macOS (verificação manual) com nome, ícone, versão e bundle id corretos.

## Out of Scope

| Feature | Motivo |
| --- | --- |
| Assinatura Developer ID + notarização | Requer conta Apple Developer paga; decisão do usuário: build sem assinatura (dev) por ora |
| Suporte Intel (x64) / Universal 2 | Decisão: só arm64 (Apple Silicon) nesta iteração |
| App Store / sandbox / .pkg instalador | Fora de escopo; DMG fora da loja |
| Auto-update | Não pedido |
| Ícone de alta qualidade produzido por designer | Ícone gerado programaticamente (asset próprio simples) nesta iteração; refinamento visual é tarefa separada |
| Instalador p/ Windows/Linux | Feature futura |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Formato | DMG drag-to-Applications (hdiutil) | Decisão do usuário | y |
| Assinatura | Nenhuma (sem codesign/notarize) | Decisão; doc Avalonia: necessário só p/ distribuição sem aviso | y |
| Arquitetura | `osx-arm64`, self-contained, `UseAppHost=true` | Decisão; publish RID arm64 validado no ambiente | y |
| Bundle id | `mcgui.jpmo.dev.br` | Decisão do usuário | y |
| Versão | `0.1.0` (`CFBundleShortVersionString`/`CFBundleVersion`), default no script; CI usa versão de tag quando presente | Decisão | y |
| Nome | Bundle `Midnight Commander GUI.app`; executável interno `mc-gui` (`CFBundleExecutable`); `CFBundleName=MC GUI` (≤15 chars) e `CFBundleDisplayName=Midnight Commander GUI`; título da janela `Midnight Commander GUI` | Nome exibido pedido pelo usuário; CFBundleName limitado a 15 chars pelo macOS | y |
| Ícone | `.icns` gerado a partir de PNG 1024 programático (`packaging/icon/icon-source.png`) via `iconutil`; sem asset externo | Decisão "incluir .icns próprio"; reproducible | y |
| OutputType | Mantém `WinExe` atual (não altera csproj app); apphost forçado por `-p:UseAppHost=true` | Validado: publish gera Mach-O arm64 executável | y |
| Estrutura .app | `mc-gui.app/Contents/{MacOS (publish), Resources (mc-gui.icns), Info.plist}` | Doc oficial Avalonia macOS | y |
| Script | `packaging/build-macos.sh` idempotente, cria bundle+DMG em `artifacts/` | Local + CI reusam | y |
| CI | `.github/workflows/build-macos.yml`: `macos-14` (arm64 runner?) — se indisponível, `macos-latest` roda arm64? CI usa runner com suporte a `osx-arm64` (macos-14 arm64). Se runner não for arm64, publicar `-r osx-arm64` ainda compila (cross) e app roda? Não testável em runner não-arm. Decisão: usar `macos-14` (Apple Silicon) e documentar fallback | a confirmar na execução | n |
| Gatekeeper dev | Usuário abre com clique-direito+Abrir | Sem assinatura | y |
| Testes | Estrutura do bundle validável deterministicamente (plist `plutil -lint`, `.icns` por `iconutil`, binário Mach-O arm64, DMG criado e montável); abertura visual via execução manual | Padrão: script/gate + UAT | y |

**Open questions:** none - runner arm64 do GitHub Actions a validar na execução (registrar desvio se `macos-14` não estiver disponível); todo o resto resolvido ou assumido acima.

---

## User Stories

### P1: Script local gera .app + DMG ⭐ MVP

**User Story**: As a desenvolvedor, I want rodar um comando no repo que gera o `.app` e o DMG, so that posso distribuir/testar sem passos manuais.

**Why P1**: Base do instalador.

**Acceptance Criteria** (cada linha é um padrão EARS):

1. WHEN the script `packaging/build-macos.sh` runs successfully THEN it SHALL produce `artifacts/mc-gui.app/` with a valid bundle structure (`Contents/MacOS` com os binários publicados, `Contents/Resources` com `mc-gui.icns`, `Contents/Info.plist`). <!-- event-driven -->
2. WHEN the script runs THEN it SHALL produce `artifacts/mc-gui-0.1.0-arm64.dmg` containing the `.app`. <!-- event-driven -->
3. The script SHALL be idempotent (re-running overwrites `artifacts/` without error). <!-- ubiquitous -->
4. WHEN the script is run from any directory in the repo THEN it SHALL resolve paths relative to the repo root. <!-- event-driven -->

**Independent Test**: Rodar `./packaging/build-macos.sh`; conferir `.app` e `.dmg` em `artifacts/`.

---

### P1: Bundle macOS válido (Info.plist, ícone, binário) ⭐ MVP

**User Story**: As a usuário final, I want que o `.app` tenha identidade correta (nome, ícone, versão, bundle id) e abra no macOS, so that parece um app nativo.

**Why P1**: Sem bundle válido o DMG não serve.

**Acceptance Criteria**:

1. The bundle's `Info.plist` SHALL declare `CFBundleIdentifier = mcgui.jpmo.dev.br`, `CFBundleExecutable = mc-gui`, `CFBundleName`/`CFBundleDisplayName` = `mc-gui`, `CFBundleShortVersionString`/`CFBundleVersion` = `0.1.0`, `CFBundlePackageType = APPL`, and `NSHighResolutionCapable = true`. <!-- ubiquitous -->
2. The `Info.plist` SHALL pass `plutil -lint` with no errors. <!-- ubiquitous -->
3. The bundle SHALL contain a `mc-gui.icns` that passes `iconutil -c icns` round-trip and is referenced by `CFBundleIconFile`. <!-- ubiquitous -->
4. The executable at `Contents/MacOS/mc-gui` SHALL be a Mach-O arm64 binary (self-contained publish output). <!-- ubiquitous -->
5. WHEN the `.app` is opened on macOS arm64 THEN the app SHALL launch (visual check). <!-- event-driven -->

**Independent Test**: `plutil -lint Info.plist` ok; `file MacOS/mc-gui` → Mach-O arm64; abrir o .app.

---

### P1: Ícone do app gerado programaticamente ⭐ MVP

**User Story**: As a usuário, I want que o app tenha um ícone próprio no Dock/Finder, so that se distingue.

**Why P1**: Decisão de incluir `.icns` próprio.

**Acceptance Criteria**:

1. WHEN the script runs THEN it SHALL generate a 1024×1024 source PNG (`packaging/icon/icon-source.png`) and convert it to an `.icns` containing the standard icon sizes via `iconutil`. <!-- event-driven -->
2. The generated `.icns` SHALL be non-empty and structurally valid (iconutil succeeds). <!-- ubiquitous -->

**Independent Test**: Rodar; conferir PNG e `.icns` gerados e `iconutil -c icns` sem erro.

---

### P1: GitHub Actions workflow gera DMG ⭐ MVP

**User Story**: As a mantenedor, I want que o CI gere o DMG automaticamente, so that cada tag/branch tem artefato pronto p/ download.

**Why P1**: Automação pedida ("ambos": local + CI).

**Acceptance Criteria**:

1. The workflow SHALL run on `macos` runners, check out the repo, install .NET, and execute the same `packaging/build-macos.sh`. <!-- ubiquitous -->
2. WHEN the workflow finishes successfully THEN it SHALL upload the produced `.dmg` as a build artifact. <!-- event-driven -->
3. WHEN the workflow runs on a git tag THEN it SHALL attach the `.dmg` to a GitHub Release. <!-- event-driven -->

**Independent Test**: Push em branch → artifact DMG; tag `v0.1.0` → release com DMG.

---

## Edge Cases

- IF `artifacts/` or the `.app` already exists THEN the script SHALL clean and regenerate (no stale files). <!-- unwanted-behavior -->
- IF a version argument is provided to the script THEN the produced DMG/plist SHALL use it instead of the default `0.1.0`. <!-- event-driven -->
- IF `iconutil`, `sips`, or `hdiutil` are missing THEN the script SHALL fail with a clear message. <!-- unwanted-behavior -->
- WHEN the DMG is mounted THEN it SHALL contain `mc-gui.app` and an Applications symlink/folder for drag-to-install. <!-- event-driven -->

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| PKG-01 | P1: Script local | Design | Pending |
| PKG-02 | P1: Script local | Design | Pending |
| PKG-03 | P1: Script local | Design | Pending |
| PKG-04 | P1: Script local | Design | Pending |
| PKG-05 | P1: Bundle válido | Design | Pending |
| PKG-06 | P1: Bundle válido | Design | Pending |
| PKG-07 | P1: Bundle válido | Design | Pending |
| PKG-08 | P1: Bundle válido | Design | Pending |
| PKG-09 | P1: Bundle válido | Design | Pending |
| PKG-10 | P1: Ícone | Design | Pending |
| PKG-11 | P1: Ícone | Design | Pending |
| PKG-12 | P1: CI | Design | Pending |
| PKG-13 | P1: CI | Design | Pending |
| PKG-14 | P1: CI | Design | Pending |

**ID format:** `PKG-N` (Packaging)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 14 total, 0 mapped to tasks, 14 unmapped ⚠️

---

## Success Criteria

- [ ] `./packaging/build-macos.sh` gera `.app` válido + `mc-gui-0.1.0-arm64.dmg`; DMG monta com app e atalho Applications.
- [ ] `plutil -lint` limpo; binário Mach-O arm64; `.icns` válido; app abre visualmente.
- [ ] Workflow CI produz DMG como artefato (e release em tag).
- [ ] Full gate existente continua verde (nenhuma mudança em código de runtime).
