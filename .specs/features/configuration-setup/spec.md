# Configuration / Setup Dialogs Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje tem configuração mínima (apenas tema Light/Dark/System via menu). O Midnight Commander original possui um sistema de configuração extensivo acessível via `Options > Configuration` (F9 > Options > Configuration) e `Options > Layout` / `Options > Panel options` / `Options > Confirmation` / `Options > Appearance` / `Options > Learn keys` / `Options > Virtual FS`, permitindo controlar centenas de opções: comportamento de painéis, confirmações, aparência, keymaps, codepages, VFS, etc. O setup é salvo em `~/.config/mc/ini` e carregado no startup. Esta feature entrega o sistema de configuração no mc-gui: diálogo de configuração unificado (abas por categoria), persistência em JSON, keymap editor (Learn keys), codepage/encoding selector, VFS config, e migração de config do MC original.

## Goals

- [ ] Menu `Options > Configuration` habilitado; abre diálogo de configuração com abas: `General`, `Panels`, `Confirmation`, `Appearance`, `Keymap`, `Codepages`, `VFS`, `Advanced`.
- [ ] Aba `General`: auto-save setup on exit (checkbox), safe delete (default No), safe overwrite (default No), confirm exit, confirm execute, auto menu, drop menus, confirm view dir, editor ask filename, tab spacing, mouse move pages, scroll pages/center, navigate with arrows, fast reload.
- [ ] Aba `Panels`: show mini-info, kilobyte SI (1000 vs 1024), mix all files, show backups, show dot files, filetype mode, permission mode, quick search mode, select flags (case sensitive, shell patterns), mark moves down, reverse files only, startup left/right mode (listing/tree/brief/long/user).
- [ ] Aba `Confirmation`: delete, overwrite, execute, exit, hotlist delete, view dir with marked files.
- [ ] Aba `Appearance`: skin/theme (já coberto por theming feature), show mini-status, line state, visible tabs/tws, show right margin, simple statusbar, check NL at EOF.
- [ ] Aba `Keymap`: editor "Learn keys" — tabela de ações vs teclas (F1-F10, Ctrl+, Alt+, chords); botão "Learn" captura próxima tecla; reset to defaults; export/import keymap JSON.
- [ ] Aba `Codepages`: display codepage (UTF-8 default), source codepage (auto), filesystem encoding, auto-detect options.
- [ ] Aba `VFS`: enable FTP, SFTP, Shell link, tar/cpio/zip plugins; FTP passive mode, timeout, proxy settings; SFTP key auth defaults.
- [ ] Aba `Advanced`: config file path, log level, debug flags, experimental features toggles.
- [ ] Botões: `OK` (aplica e salva), `Cancel` (descarta), `Apply` (aplica sem fechar), `Reset to defaults` (com confirmação).
- [ ] Persistência em `~/.config/mc-gui/settings.json` (JSON estruturado); carrega no startup; migração opcional de `~/.config/mc/ini` (MC original).
- [ ] Mudanças aplicadas em tempo real onde possível (ex.: tema, painel opções); outras exigem restart (ex.: codepage, VFS plugins).

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| Editor de skins/temas visual (além de Light/Dark) | Theming feature cobre Light/Dark; skins customizados futuros |
| Perfis de configuração múltiplos (work/personal) | Feature futura; single profile MVP |
| Sincronização de config entre máquinas (cloud) | Feature futura |
| Wizard de primeira execução (onboarding) | Nice-to-have; config dialog cobre |
| Importação de `.bashrc`/`.zshrc` aliases para user menu | Feature separada (User Menu) |
| Configuração por projeto (`.mcgui.json` no diretório) | Feature futura |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Formato config | JSON em `~/.config/mc-gui/settings.json` (estruturado, tipado) | Legível, versionável, validável via JSON Schema | n |
| UI do diálogo | Janela modal (`Window`) com `TabControl` (abas laterais ou topo); cada aba = `ScrollViewer` + `StackPanel` de controles | Padrão desktop; escalável para muitas opções | n |
| Controles | CheckBox (bool), ComboBox (enum), TextBox (string/int), NumericUpDown (int), ColorPicker (cores), KeyGestureEditor (keymap) | Avalonia built-ins | n |
| Keymap editor | `DataGrid` com colunas: Action, Current Key, Default Key; botão "Learn" (captura próximo KeyGesture) + "Clear" | Similar a IDEs | n |
| Migração MC ini | Parser simples para `~/.config/mc/ini` (seções `[Midnight-Commander]`, `[Panel]`, etc.) → mapeia para JSON; roda once no primeiro startup se JSON não existe | Transição suave para usuários MC | n |
| Aplicação real-time | Opções UI (tema, painel cols, mini-info) aplicam via `INotifyPropertyChanged` + listeners; opções sistema (codepage, VFS) marcam `RequiresRestart=true` | UX responsiva | n |
| Validação | JSON Schema para settings.json; valida no load/save; erros mostram toast + abrem config na aba errada | Robustez | n |
| Testes | Unit: SettingsService (load/save/migrate/validate), KeymapEditor (learn/clear/export); UAT: diálogo completo | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Diálogo de configuração com abas ⭐ MVP

**User Story**: Como usuário, quero abrir `Options > Configuration` e ver todas as opções organizadas em abas, para personalizar o mc-gui ao meu gosto.

**Why P1**: Configuração centralizada é expectativa de qualquer app desktop; MC original tem dezenas de opções.

**Acceptance Criteria**:

1. WHEN the user opens `Options > Configuration` THEN a modal dialog SHALL open with a `TabControl` containing tabs: `General`, `Panels`, `Confirmation`, `Appearance`, `Keymap`, `Codepages`, `VFS`, `Advanced`.
2. EACH tab SHALL contain logically grouped controls (CheckBox, ComboBox, TextBox, NumericUpDown) with labels and tooltips.
3. WHEN the user changes a value THEN the control SHALL show visual feedback (dirty indicator); `Apply` button SHALL enable.
4. WHEN the user clicks `OK` THEN all changes SHALL be applied, saved to `settings.json`, and dialog SHALL close.
5. WHEN the user clicks `Cancel` THEN all uncommitted changes SHALL be discarded; dialog closes.
6. WHEN the user clicks `Apply` THEN changes SHALL be applied and saved; dialog SHALL remain open.
7. WHEN the user clicks `Reset to defaults` THEN a confirmation SHALL appear; on confirm, all settings SHALL revert to hardcoded defaults.

**Independent Test**: Abrir Configuration → aba Panels → alterar "Show dot files" → Apply → fechar → reabrir → mudança persistida; Reset → volta ao default.

---

### P1: Keymap Editor (Learn keys) ⭐ MVP

**User Story**: Como usuário power user, quero remapear teclas (F1-F10, Ctrl+, Alt+, chords) via interface visual "Learn keys", para adaptar atalhos ao meu workflow.

**Why P1**: Keymap customizável é feature icônica do MC; "Learn keys" é único.

**Acceptance Criteria**:

1. THE `Keymap` tab SHALL display a `DataGrid` with columns: `Action` (descrição), `Current Key` (editable), `Default Key` (read-only).
2. ACTIONS SHALL include all `GestureAction` values: `Help`, `UserMenu`, `View`, `Edit`, `Copy`, `Move`, `Mkdir`, `Delete`, `Menu`, `Quit`, `Rescan`, `Select`, `Unselect`, `Invert`, `SwapPanels`, `SwitchPanels`, `QuickCd`, `CommandLine`, `BackgroundJobs`, `DirectoryTree`, `FindFile`, `CompareFiles`, `CompareDirs`, `Hotlist`, `VFSList`, `EditExtensionFile`, `EditMenuFile`, `EditHighlightFile`, `PanelLeft`, `PanelRight`, `PanelQuickView`, `PanelInfo`, `PanelTree`, `PanelPanelize`, `PanelFormat`, `PanelSort`, `PanelFilter`, `PanelEncoding`, `PanelFTPLink`, `PanelShellLink`, `PanelSFTPLink`, `PanelRescan`.
3. WHEN the user double-clicks `Current Key` cell THEN it SHALL enter edit mode; pressing a key combination (e.g., `Ctrl+Shift+P`) SHALL update the cell and validate (no conflicts with existing bindings).
4. WHEN the user clicks `Learn` button THEN the dialog SHALL enter "capture mode": next key press SHALL be recorded as the binding for the selected action; Esc cancels capture.
5. WHEN the user clicks `Clear` on a row THEN the binding SHALL be removed (action unbound).
6. BUTTONS `Export` / `Import` SHALL save/load keymap as JSON (`keymap.json`) for backup/sharing.

**Independent Test**: Keymap tab → encontra "Copy" → Current Key "F5" → Learn → pressiona `Ctrl+Shift+C` → Cell atualiza → OK → `Ctrl+Shift+C` agora abre Copy dialog.

---

### P1: Migração de config do MC original ⭐ MVP

**User Story**: Como usuário migrante do MC terminal, quero que minhas configurações antigas (`~/.config/mc/ini`) sejam importadas automaticamente, para não reconfigurar tudo.

**Why P1**: Reduz atrito de migração; MC tem base de usuários fiel.

**Acceptance Criteria**:

1. ON first startup (no `settings.json` exists), the app SHALL check for `~/.config/mc/ini` (or `~/.mc/ini`).
2. IF found, a migration dialog SHALL appear: "Found Midnight Commander configuration. Import settings?" with `Yes` / `No` / `View mapping`.
3. IF `Yes`, the parser SHALL map known keys: `[Midnight-Commander]` → General/Confirmation; `[Panel]` → Panels; `[Layout]` → Appearance; `[Keymap]` → Keymap; `[Codepage]` → Codepages; `[VFS]` → VFS.
4. UNMAPPED keys SHALL be logged to migration report (viewable via `View mapping`).
5. AFTER import, `settings.json` SHALL be created; subsequent startups use JSON directly.
6. IF `settings.json` already exists, migration SHALL NOT run automatically (user can trigger via `Advanced > Migrate from MC ini`).

**Independent Test**: Copiar `~/.config/mc/ini` real → primeiro start mc-gui → dialog aparece → Yes → config importada; keymap, painéis, confirmações preservadas.

---

### P2: Validação, restart hints, e export/import ⭐ MVP

**User Story**: Como usuário, quero validação de config, avisos de restart necessário, e poder exportar/importar minha config.

**Why P2**: Robustez e portabilidade de config.

**Acceptance Criteria**:

1. WHEN a setting requires restart (Codepages, VFS plugins, Keymap structural changes) THEN the control SHALL show a restart icon ⚠️ and `Apply` SHALL show "Restart required" badge.
2. THE `Advanced` tab SHALL have `Export settings` (saves `settings.json` + `keymap.json` to chosen folder) and `Import settings` (loads from folder, validates, applies).
3. VALIDATION on load/save: JSON Schema validation; invalid values SHALL show inline error on respective control + toast summary.
4. CONFIG file path SHALL be shown in `Advanced` (read-only); `Open config folder` button opens `~/.config/mc-gui/` in system file manager.

---

## Edge Cases

- IF the user enters invalid value in NumericUpDown (out of range) THEN control SHALL clamp to min/max and show tooltip.
- IF keymap has conflict (two actions bound to same key) THEN `Learn`/edit SHALL show warning and prevent save until resolved.
- IF migration finds corrupted `ini` THEN parser SHALL skip bad lines, log warnings, continue with valid keys.
- IF `settings.json` is manually edited and corrupted THEN app SHALL show recovery dialog: "Config corrupted. Reset to defaults?" with `Yes`/`No`/`Open folder`.
- MAXIMUM tab spacing: 16; minimum: 1.
- COLORPICKER for Appearance: usa tema atual (Light/Dark) para preview.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| CFG-01 | P1: Diálogo abas | Specify | Pending |
| CFG-02 | P1: Diálogo abas | Specify | Pending |
| CFG-03 | P1: Diálogo abas | Specify | Pending |
| CFG-04 | P1: Diálogo abas | Specify | Pending |
| CFG-05 | P1: Diálogo abas | Specify | Pending |
| CFG-06 | P1: Diálogo abas | Specify | Pending |
| CFG-07 | P1: Diálogo abas | Specify | Pending |
| CFG-08 | P1: Keymap Editor | Specify | Pending |
| CFG-09 | P1: Keymap Editor | Specify | Pending |
| CFG-10 | P1: Keymap Editor | Specify | Pending |
| CFG-11 | P1: Keymap Editor | Specify | Pending |
| CFG-12 | P1: Keymap Editor | Specify | Pending |
| CFG-13 | P1: Migração MC ini | Specify | Pending |
| CFG-14 | P1: Migração MC ini | Specify | Pending |
| CFG-15 | P1: Migração MC ini | Specify | Pending |
| CFG-16 | P1: Migração MC ini | Specify | Pending |
| CFG-17 | P1: Migração MC ini | Specify | Pending |
| CFG-18 | P2: Validação/Restart/Export | Specify | Pending |
| CFG-19 | P2: Validação/Restart/Export | Specify | Pending |
| CFG-20 | P2: Validação/Restart/Export | Specify | Pending |
| CFG-21 | P2: Validação/Restart/Export | Specify | Pending |

**ID format:** `CFG-NN` (Configuration)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 21 total, 0 mapped to tasks, 21 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] `Options > Configuration` abre diálogo com 8 abas; todas as opções MC mapeadas; OK/Cancel/Apply/Reset funcionam.
- [ ] Keymap tab: DataGrid com todas as ações; Learn/Clear/Export/Import funcionam; conflitos detectados.
- [ ] Migração `mc.ini` → `settings.json` automática no primeiro run; mapping report visível.
- [ ] Validação JSON Schema; restart hints visíveis; Export/Import settings funcionam.
- [ ] Mudanças real-time onde aplicável; restart required badge correto.
- [ ] Suite de testes existente (236) continua passando; novos testes: SettingsService, KeymapEditor, Migration.
- [ ] Build com `-warnaserror` limpo.