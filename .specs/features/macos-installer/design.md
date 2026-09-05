# macOS Installer Design

> Decisão de arquitetura para a feature `macos-installer`. Leitura complementar: `spec.md`.

## Visão geral

Empacotamento do app Avalonia em `.app` + DMG via um script shell idempotente + workflow GitHub Actions reutilizando o mesmo script. Build sem assinatura, arm64, self-contained.

```
packaging/
├── build-macos.sh          # publish + monta .app + gera DMG (usa geração de ícone)
├── Info.plist              # template do bundle
├── make-icon.sh            # gera icon-source.png (PIL) + converte p/ mc-gui.icns
└── icon/
    └── mc-gui.icns         # (gerado, commitado? não — regenerado no build)
.github/workflows/build-macos.yml   # CI: roda build-macos.sh, sobe artefato, release em tag
artifacts/  (gerado, gitignored)
```

## Decisões

### D1. Script `build-macos.sh`

- Passos: (1) limpa `artifacts/`; (2) `dotnet publish -c Release -r osx-arm64 --self-contained true -p:UseAppHost=true -o artifacts/publish`; (3) monta `artifacts/mc-gui.app/Contents/{MacOS,Resources}`; copia publish→MacOS; Info.plist→Contents; `.icns`→Resources; cria `Contents/MacOS/mc-gui` (o apphost já se chama `McGui.App`? — **decisão D2**); (4) `hdiutil create` DMG com app + link Applications; (5) `plutil -lint`, `file` do binário, `iconutil` como auto-checks; falha com mensagem clara se ferramenta ausente.
- Versão: `VERSION=${1:-0.1.0}`; nome do DMG `mc-gui-${VERSION}-arm64.dmg`.
- Idempotente: `rm -rf artifacts/` no início.
- Paths relativos: script resolve próprio dir (`SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)`; repo root = `$SCRIPT_DIR/..`).

**Por quê**: um único script reutilizável por local e CI (spec PKG-01..04, PKG-12..14).

### D2. Nome do executável e binário

- Publish gera apphost `McGui.App` (nome do assembly). O `.app` precisa `CFBundleExecutable` batendo com o binário real.
- Decisão: **renomear** o executável dentro do bundle p/ `mc-gui`? O apphost interno espera o `.dll` `McGui.App.dll` (fica no mesmo dir). Renomear o host mach-o é seguro (o host localiza `McGui.App.dll`). **Decisão**: copiar publish e renomear `McGui.App` → `mc-gui` em `Contents/MacOS/`, e `CFBundleExecutable=mc-gui`. Alternativa mais simples: manter `McGui.App` e `CFBundleExecutable=McGui.App` com `CFBundleName=mc-gui`. Renomear o executável do bundle é o padrão (usuário vê `mc-gui` no bundle). Valida-se na execução que o host renomeado abre.

### D3. Info.plist

Template estático commitado em `packaging/Info.plist` com `CFBundleIdentifier=mcgui.jpmo.dev.br`, `CFBundleName=mc-gui`, `CFBundleDisplayName=mc-gui`, `CFBundleShortVersionString`/`CFBundleVersion` = `${VERSION}` (o script injeta via `sed`/`plutil`), `CFBundlePackageType=APPL`, `NSHighResolutionCapable=true`, `CFBundleIconFile=mc-gui.icns`, `CFBundleExecutable=mc-gui`. `LSMinimumSystemVersion=12.0` (Avalonia 12 requer macOS ≥10.15; 12 é seguro).

**Por quê**: keys mínimas exigidas pela doc Avalonia (spec PKG-05).

### D4. Ícone programático

- `make-icon.sh`: usa Python (PIL, disponível) p/ desenhar PNG 1024×1024 simples (fundo arredondado escuro + dois painéis de "arquivos" estilo MC ou `../` + pasta) → `artifacts/build/icon-source.png`; `sips -z` gera os tamanhos do iconset; `iconutil -c icns` produz `mc-gui.icns`.
- PNG desenhado em Python = deterministic, sem asset binário externo (spec PKG-10..11).

### D5. DMG drag-to-install

- `hdiutil create` com volume `mc-gui`, conteúdo: `mc-gui.app` + symlink/folder `/Applications`. Layout AppleScript `tell app "Finder"` opcional p/ posicionar — manter simples: `hdiutil create ... -srcfolder` com dir preparado contendo app e link p/ /Applications. Sem AppleScript (menos frágil em CI). Formato `UDZO`.

### D6. CI workflow

- `build-macos.yml`: `runs-on: macos-14` (arm64). Passos: checkout, setup-dotnet (10.x), `chmod +x packaging/*.sh`, `./packaging/build-macos.sh` (versão do tag se `v*`, senão `0.1.0`), upload-artifact do `.dmg`; em tag, `softprops/action-gh-release` ou `gh release upload`.
- Fallback: se `macos-14` indisponível, usar `macos-latest` (cross-publish `osx-arm64` compila; execução visual não validável em runner x64 — registrar).

### D7. Gitignore

- Adicionar `artifacts/` ao `.gitignore`. Não commitar `.icns`/DMG gerados.

### D8. Verificação

- Auto-checks no script (fence determinístico): `plutil -lint` (exit), `file MacOS/mc-gui` contém `arm64`, `test -s Resources/mc-gui.icns`, DMG monta (`hdiutil attach -nobrowse` + verifica app + detach) — opcional em CI por custo; no mínimo verificação local de montagem na task.
- UAT: abrir `mc-gui.app` do DMG montado (visual), conferir ícone/nome/versão no Finder.

## Arquivos afetados

- novo `packaging/build-macos.sh`
- novo `packaging/Info.plist`
- novo `packaging/make-icon.sh`
- novo `.github/workflows/build-macos.yml`
- `.gitignore` (+ `artifacts/`)
- testes: nenhum xunit novo (empacotamento validado por auto-checks do script + UAT); suíte existente deve permanecer verde
