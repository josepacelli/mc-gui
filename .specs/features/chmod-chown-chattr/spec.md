# Chmod / Chown / Chattr Dialogs Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje não tem diálogos para alterar permissões (chmod), dono/grupo (chown), ou atributos estendidos (chattr/lsattr). O Midnight Commander original possui diálogos completos acessíveis via `File > chmod` (Ctrl+X, C), `File > chown` (Ctrl+X, O), e `File > chattr` (Ctrl+X, A), que permitem: chmod com matriz de checkboxes (owner/group/other × read/write/execute + setuid/setgid/sticky) + entrada octal; chown com entrada de usuário/grupo (resolução de nome/UID/GID); chattr com lista de atributos (immutable, append-only, no-dump, etc.) via `lsattr`/`chattr`. Esta feature entrega os três diálogos no mc-gui, acessíveis via menu `File > chmod/chown/chttr` e atalhos, com: UI nativa Avalonia, aplicação recursiva opcional, suporte a múltiplos arquivos marcados, e integração com `IFileSystemService`.

## Goals

- [ ] Menu `File > chmod` habilitado; atalho `Ctrl+X, C` (ou `F9` > File > chmod) abre diálogo de permissões.
- [ ] Diálogo chmod: matriz 3x4 de checkboxes (Owner/Group/Other × Read/Write/Execute + Special: setuid/setgid/sticky), entrada octal sincronizada bidirecionalmente, preview da string `rwxrwxrwt`.
- [ ] Opção "Apply recursively" (checkbox) para aplicar a diretórios e subconteúdo.
- [ ] Opção "Apply to marked files only" (checkbox, default se houver marcados) vs arquivo sob cursor.
- [ ] Botão "Set all" aplica mesma permissão a owner/group/other; "Marked all" marca todos checkboxes; "Set marked"/"Clear marked" para seleção rápida.
- [ ] Menu `File > chown` habilitado; atalho `Ctrl+X, O` abre diálogo de owner/group.
- [ ] Diálogo chown: campos Owner (username ou UID) e Group (groupname ou GID) com autocomplete a partir de `/etc/passwd`/`/etc/group` (ou Directory Services no macOS); botão "Same as current" copia do arquivo sob cursor.
- [ ] Opção recursiva e "marked files" igual ao chmod.
- [ ] Menu `File > chattr` habilitado; atalho `Ctrl+X, A` abre diálogo de atributos estendidos.
- [ ] Diálogo chattr: lista de checkboxes para atributos suportados no SO (macOS: `uchg`/`schg` immutable, `uappnd`/`sappnd` append-only, `nodump`, `opaque`, `hidden`; Linux: `i` immutable, `a` append-only, `d` no-dump, `c` compressed, `e` extent format, `j` journal, `s` secure deletion, `t` no-tail-merging, `u` undeletable, `A` no-atime).
- [ ] Botão "Get attributes" (lsattr) lê atributos atuais do arquivo sob cursor e preenche checkboxes.
- [ ] Aplicação via `IFileSystemService` com suporte a VFS (onde suportado: chmod/chown em FTP/SFTP; chattr apenas local).
- [ ] Progress dialog para operações recursivas em muitos arquivos; Cancel para abortar.

## Out of Scope

Explicitamente excluído desta feature.

| Feature | Motivo |
| --- | --- |
| ACLs (Access Control Lists) `getfacl`/`setfacl` | Complexidade maior; macOS/Linux/Windows têm APIs diferentes; feature futura |
| xattrs (extended attributes) genéricos | macOS `xattr`/Linux `xattr`/Windows alternate data streams; feature futura |
| Capabilities (Linux `getcap`/`setcap`) | Específico Linux; feature futura |
| Preservação de timestamps durante chown/chmod | Já coberto por copy/move PreserveAttributes; chmod/chown não altera timestamps por padrão |
| Integração com sudo/pkexec para root | Fora do escopo; usuário roda app com permissões necessárias |
| Chmod/chown em arquivos dentro de archives (tar) | VFS write não suportado no MVP |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| UI | Diálogos modais (`Window`) com `Grid`/`StackPanel` para layout; `UniformGrid` para matriz chmod | Consistente com outros diálogos mc-gui | n |
| Chmod matrix | 4 linhas (Owner, Group, Other, Special) × 4 colunas (Read, Write, Execute, Special bits) | MC original usa 12 checkboxes; reorganizado para clareza | n |
| Octal sync | TextBox octal (ex.: `0755`) bidirecional: digitar octal atualiza checkboxes; clicar checkbox atualiza octal | Feedback imediato | n |
| User/Group lookup | macOS: `dscl` / `dseditgroup`; Linux: `/etc/passwd`/`/etc/group` cache; Windows: não aplicável (chown não existe) | AD-001: implementação por SO | n |
| Chattr attributes | Descobre dinamicamente via `chattr -h` (Linux) ou `man chflags` (macOS); fallback lista hardcoded | Portabilidade | n |
| Recursão | `IFileSystemService` ganha `ChangePermissionsAsync`, `ChangeOwnerAsync`, `ChangeAttributesAsync` com `recursive` flag | Reutiliza infraestrutura copy/move | n |
| Múltiplos arquivos | Se houver marcados → aplica a todos; senão → arquivo sob cursor; progress dialog agregado | Consistente com copy/move | n |
| Testes | Unit: permission matrix logic, octal↔checkbox sync, owner lookup; Integration: chmod/chown/chattr recursivo em temp dir; UAT: diálogos | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Diálogo chmod (permissões) ⭐ MVP

**User Story**: Como usuário, quero pressionar Ctrl+X,C e alterar permissões de arquivos/diretórios via matriz visual ou octal, com opção recursiva, para controlar acesso.

**Why P1**: chmod é operação fundamental de Unix; menu File > chmod existe desabilitado no menubar.

**Acceptance Criteria**:

1. WHEN the user opens the chmod dialog (menu or shortcut) THEN it SHALL display: file name, current permissions as 12 checkboxes (Owner/Group/Other × R/W/X + Special: setuid/setgid/sticky), octal TextBox (e.g., `0755`), symbolic preview (e.g., `rwxr-xr-x`), and checkboxes "Recursive" and "Apply to marked files".
2. WHEN the user toggles a checkbox THEN the octal TextBox and symbolic preview SHALL update immediately.
3. WHEN the user types a valid octal in the TextBox THEN the checkboxes SHALL update to match.
4. WHEN the user clicks "Set all" THEN all three classes (Owner, Group, Other) SHALL receive the same R/W/X bits (Special bits unchanged).
5. WHEN the user clicks "Marked all" THEN all 12 checkboxes SHALL be checked; "Clear marked" SHALL uncheck all.
6. WHEN the user clicks "Set marked" THEN only currently checked boxes SHALL be applied (OR mask); "Clear marked" applies AND-NOT mask.
7. WHEN the user confirms THEN the system SHALL apply permissions via `IFileSystemService.ChangePermissionsAsync` with recursive/marked options; progress dialog shows for recursive ops.

**Independent Test**: Selecionar pasta, Ctrl+X,C → matrix mostra perms atuais; alterar para 0755 via octal → checkboxes sincronizam; Recursive + OK → progress dialog → `ls -l` confirma.

---

### P1: Diálogo chown (dono/grupo) ⭐ MVP

**User Story**: Como usuário, quero alterar dono e grupo de arquivos via diálogo com autocomplete de usuários/grupos do sistema.

**Why P1**: chown complementa chmod; essencial para admin de arquivos.

**Acceptance Criteria**:

1. THE chown dialog SHALL show: file name, current owner:group, Owner field (TextBox with autocomplete dropdown of system users), Group field (TextBox with autocomplete dropdown of system groups), checkboxes "Recursive" and "Apply to marked files".
2. THE autocomplete SHALL query system user/group database (macOS: `dscl . list /Users` / `dscl . list /Groups`; Linux: `/etc/passwd` `/etc/group`) and filter as user types.
3. WHEN the user clicks "Same as current" THEN Owner/Group fields SHALL be filled with the current file's owner/group.
4. WHEN the user enters a numeric UID/GID (no name match) THEN it SHALL be accepted as-is (validated as number).
5. CONFIRMATION applies via `IFileSystemService.ChangeOwnerAsync` with recursive/marked options.

**Independent Test**: chown dialog → digita "us" → sugere "user1", "user2"; seleciona → Group autocomplete similar; OK → `ls -l` mostra novo dono.

---

### P1: Diálogo chattr (atributos estendidos) ⭐ MVP

**User Story**: Como usuário (admin), quero definir atributos como immutable/append-only em arquivos sensíveis, para proteção contra modificação acidental.

**Why P1**: chattr é poderosa proteção; MC original tem; GUI moderna deve expor.

**Acceptance Criteria**:

1. THE chattr dialog SHALL show: file name, current attributes (read-only display from `lsattr`/`GetFileAttributes`), checklist of supported attributes for the OS (macOS: `uchg` immutable, `uappnd` append-only, `nodump`, `opaque`, `hidden`; Linux: `i` immutable, `a` append-only, `d` no-dump, `c` compressed, `j` journal, `s` secure delete, `u` undeletable, `A` no-atime, `t` no-tail-merging), checkboxes "Recursive", "Apply to marked files".
2. BUTTON "Get attributes" SHALL run `lsattr` / `GetFileAttributes` on the file under cursor and check corresponding boxes.
3. CHECKBOXES SHALL be tristate: Unchecked (clear), Checked (set), Indeterminate (keep current / don't change) — default Indeterminate.
4. CONFIRMATION applies via `IFileSystemService.ChangeAttributesAsync` with recursive/marked options; only Checked/Unchanged (not Indeterminate) are sent.
5. IF the OS/filesystem doesn't support an attribute THEN its checkbox SHALL be disabled with tooltip.

**Independent Test**: chattr em arquivo → Get attributes mostra vazio; marca `uchg` (immutable) → OK → `ls -lO` mostra `uchg`; tenta editar → "Operation not permitted".

---

### P2: Integração com menubar e atalhos ⭐ MVP

**User Story**: Como usuário, quero acessar chmod/chown/chattr via menu `File` e atalhos `Ctrl+X` sequenciais, consistente com MC.

**Why P2**: Menubar já tem itens desabilitados; atalhos MC são `Ctrl+X` + letra.

**Acceptance Criteria**:

1. THE `File > chmod`, `File > chown`, `File > chattr` menu items SHALL be enabled.
2. THE shortcuts `Ctrl+X,C` (chmod), `Ctrl+X,O` (chown), `Ctrl+X,A` (chattr) SHALL open respective dialogs (sequential chord: press Ctrl+X, release, press C/O/A).
3. THE dialogs SHALL respect the active panel's selection (marked files or cursor file).
4. KEYBOARD navigation in dialogs: Tab/Shift+Tab, Space (toggle checkbox), Enter (confirm), Esc (cancel).

---

## Edge Cases

- IF the user runs chmod/chown on a read-only filesystem THEN the operation SHALL fail gracefully with error "Read-only file system"; no partial changes.
- IF the user enters invalid octal (non-octal digits, >4 digits) THEN the TextBox SHALL show validation error and disable OK.
- IF chown user/group doesn't exist THEN autocomplete SHALL not prevent entry (numeric UID/GID allowed); OS will reject on apply with "Invalid argument".
- IF chattr attribute not supported by filesystem (e.g., `immutable` on FAT32) THEN checkbox disabled; apply SHALL skip unsupported with warning in progress log.
- RECURSIVE on symlink: SHALL follow symlink to target directory (MC behavior) or act on link? MC acts on target for chmod/chown. This feature: follow symlink for dirs, act on link for files (configurable? default: follow for dirs).
- PERMISSION DENIED on some files during recursive: SHALL skip failed, continue others, aggregate errors in progress log (same as copy/move).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| CHM-01 | P1: chmod dialog | Specify | Pending |
| CHM-02 | P1: chmod dialog | Specify | Pending |
| CHM-03 | P1: chmod dialog | Specify | Pending |
| CHM-04 | P1: chmod dialog | Specify | Pending |
| CHM-05 | P1: chmod dialog | Specify | Pending |
| CHM-06 | P1: chmod dialog | Specify | Pending |
| CHM-07 | P1: chmod dialog | Specify | Pending |
| CHM-08 | P1: chown dialog | Specify | Pending |
| CHM-09 | P1: chown dialog | Specify | Pending |
| CHM-10 | P1: chown dialog | Specify | Pending |
| CHM-11 | P1: chown dialog | Specify | Pending |
| CHM-12 | P1: chattr dialog | Specify | Pending |
| CHM-13 | P1: chattr dialog | Specify | Pending |
| CHM-14 | P1: chattr dialog | Specify | Pending |
| CHM-15 | P1: chattr dialog | Specify | Pending |
| CHM-16 | P2: Menubar/Atalhos | Specify | Pending |
| CHM-17 | P2: Menubar/Atalhos | Specify | Pending |
| CHM-18 | P2: Menubar/Atalhos | Specify | Pending |
| CHM-19 | P2: Menubar/Atalhos | Specify | Pending |

**ID format:** `CHM-NN` (Chmod/Chown/Chattr)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 19 total, 0 mapped to tasks, 19 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] `File > chmod` (Ctrl+X,C) abre diálogo com matriz 12 checkboxes + octal sync; Set all/Marked all/Set marked/Clear marked funcionam; Recursive + marked options; progress dialog.
- [ ] `File > chown` (Ctrl+X,O) abre diálogo com Owner/Group autocomplete (sistema); Same as current; Recursive + marked; progress.
- [ ] `File > chattr` (Ctrl+X,A) abre diálogo com atributos do OS; Get attributes; tristate checkboxes; Recursive + marked; progress.
- [ ] Menus habilitados; atalhos `Ctrl+X,C/O/A` funcionais; navegação teclado.
- [ ] Operações aplicam via `IFileSystemService`; VFS (FTP/SFTP) chmod/chown onde suportado.
- [ ] Suite de testes existente (236) continua passando; novos testes: unit matrix/octal, owner lookup, attr list; integração recursiva.
- [ ] Build com `-warnaserror` limpo.