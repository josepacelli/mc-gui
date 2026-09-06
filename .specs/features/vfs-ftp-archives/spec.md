# VFS (FTP/SFTP/Archives) Specification

> As linhas de Acceptance Criteria seguem a notação EARS em inglês (convenção da técnica + compatibilidade com o validador `validate_spec.py`). O restante do documento está em português.

## Problem Statement

O mc-gui hoje só acessa sistema de arquivos local via `IFileSystemService` + `MacFileSystemService`. O Midnight Commander original possui um sistema VFS (Virtual File System) modular com plugins para: FTP (`ftpfs`), SFTP/SSH (`sftpfs`), arquivos tar (`.tar`, `.tar.gz`, `.tar.bz2`, `.tar.xz`), cpio, RPM, ZIP, e shell links. O VFS permite navegar dentro de arquivos compactados e servidores remotos como se fossem diretórios locais, com operações de arquivo transparentes (copiar, mover, editar, visualizar). Esta feature (fatia A) entrega a arquitetura VFS no mc-gui com plugins para: FTP, SFTP, e arquivos tar/gzip/bzip2/xz (leitura/navegação). Escrita em arquivos compactados e plugins adicionais (cpio, rpm, zip, shell) ficam para fases futuras.

## Goals

- [ ] Arquitetura VFS extensível no `McGui.Core` com interface `IVfsPlugin` e registro de plugins por esquema/extensão.
- [ ] Plugin FTP (`ftp://`) com suporte a: login anônimo/usuário+senha, listagem de diretórios, download/upload de arquivos, navegação passiva/ativa.
- [ ] Plugin SFTP (`sftp://` ou `ssh://`) via SSH.NET: autenticação por senha/chave, listagem, download/upload, navegação.
- [ ] Plugin Tar (`tar://`, `.tar`, `.tar.gz`, `.tgz`, `.tar.bz2`, `.tbz2`, `.tar.xz`, `.txz`): navegação somente-leitura dentro do arquivo, listagem, extração de arquivos para sistema local.
- [ ] Integração transparente: `IFileSystemService.ListDirectory` detecta VFS path e delega ao plugin correto; painéis mostram conteúdo VFS indistinguível de local.
- [ ] Credenciais: diálogo de login para FTP/SFTP na primeira conexão; opção de salvar no keychain/credential manager do SO.
- [ ] Barra de status do painel mostra indicador VFS (ex.: `[ftp]`, `[tar]`) e caminho virtual.
- [ ] Operações suportadas em VFS: Copy (download/upload), View (F3), Edit (F4 - download temp, edit, upload), Delete (remoto), Mkdir (remoto). Move/Rename apenas se mesmo servidor.
- [ ] Cache de listagem VFS com TTL configurável; botão "Rescan" (F2/Rescan) invalida cache.

## Out of Scope

Explicitamente excluído desta feature (fatias futuras separadas).

| Feature | Motivo |
| --- | --- |
| Escrita em arquivos compactados (criar/modificar .tar.gz) | Complexidade de streaming write; só leitura/navegação no MVP |
| Plugins cpio, RPM, ZIP, LHA, RAR | Prioridade menor; tar cobre maioria dos casos Unix |
| Shell link (`sh://`) | Exige execução remota de comandos; feature futura |
| VFS extfs (scripts externos) | Arquitetura específica do MC terminal; não portável direto |
| Proxy FTP/HTTP | Configuração avançada; fora do MVP |
| Background transfer queue | Feature separada (Background Operations) |
| Sincronização de diretórios remotos | Feature futura (compare dirs) |
| Bookmarks VFS no hotlist | Hotlist é feature separada |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Interface VFS | `IVfsPlugin` no `McGui.Core.Interfaces` com `Scheme`, `CanHandle(path)`, `ListDirectory`, `ReadFile`, `WriteFile`, `Delete`, `CreateDirectory`, `GetFileInfo` | Abstração limpa; plugins no `McGui.Infrastructure.macOS` ou projeto dedicado | n |
| Detecção de VFS path | Prefixo `scheme://` (ftp://, sftp://, tar://) OU extensão conhecida (.tar.gz, .tgz, etc.) para arquivos locais | MC usa `vfs_path_t` com esquema; GUI usa convenção similar | n |
| Tar plugin | `SharpCompress` ou `System.IO.Compression` + custom tar reading; navegação read-only | Bibliotecas .NET maduras; evita reimplementar tar | n |
| FTP/SFTP lib | `FluentFTP` para FTP; `SSH.NET` para SFTP — ambas maduras, MIT/BSD | Padrão no ecossistema .NET | n |
| Credenciais | `ICredentialStore` interface no Core; implementação macOS usa Keychain (`SecRecord`); Windows usa Credential Manager; Linux usa libsecret | AD-001: isolar código de SO | n |
| Cache | `MemoryCache` com TTL 30s default; invalidado por Rescan ou operação de escrita | Equilíbrio performance/frescor | n |
| Progresso | Operações VFS longas (download/upload) usam `IProgress<OperationProgress>` existente; janela de progresso modal | Reutiliza infraestrutura copy/move | n |
| Testes | Unit tests com servidores mock (Testcontainers ou mock FTP/SFTP); UAT com servidor real | Padrão do projeto | n |

**Open questions:** none - todas resolvidas ou registradas acima.

---

## User Stories

### P1: Arquitetura VFS + Plugin Local Tar ⭐ MVP

**User Story**: Como usuário, quero navegar dentro de arquivos `.tar.gz`/`.tar.bz2`/`.tar.xz` como se fossem pastas, para extrair/visualizar arquivos sem extrair manualmente.

**Why P1**: Arquivos tar são ubíquos no Unix; navegação read-only é base do VFS.

**Acceptance Criteria**:

1. WHEN the user presses Enter on a `.tar.gz` file in the panel THEN the panel SHALL navigate into the archive showing its contents as a virtual directory with path like `tar:///path/to/archive.tar.gz/`.
2. WHEN inside a tar archive THEN the panel SHALL display files/directories with names, sizes, permissions, and timestamps from the archive metadata.
3. WHEN the user presses F3 (View) on a file inside the archive THEN the viewer SHALL open the extracted content in a temporary file.
4. WHEN the user presses F5 (Copy) on file(s) inside the archive THEN the system SHALL extract and copy to the destination panel (local or other VFS).
5. THE panel status line SHALL show `[tar]` indicator and the virtual path.
6. WHEN the user presses Backspace or `..` at archive root THEN the panel SHALL return to the parent directory (the directory containing the archive file).

**Independent Test**: Navegar para um `.tar.gz`, Enter entra no arquivo, lista conteúdo, F3 abre arquivo interno, F5 copia para painel local, Backspace sai do arquivo.

---

### P1: Plugin FTP ⭐ MVP

**User Story**: Como usuário, quero conectar a servidores FTP (`ftp://user@host/path`) e navegar/transferir arquivos, para gerenciar servidores remotos.

**Why P1**: FTP ainda é comum para deploy/servidores legados; plugin independente.

**Acceptance Criteria**:

1. WHEN the user types `ftp://` in the panel path input (Ctrl+X, H ou quick cd) THEN a login dialog SHALL appear requesting user/password (anonymous default).
2. AFTER successful login THEN the panel SHALL display the remote directory listing with `[ftp]` indicator.
3. WHEN the user navigates (Enter on dir, Backspace/`..`) THEN listings SHALL be fetched from server with cache.
4. WHEN the user copies file from local to FTP (F5) THEN upload SHALL occur with progress dialog.
5. WHEN the user copies file from FTP to local (F5) THEN download SHALL occur with progress dialog.
6. WHEN the user deletes (F8) on FTP THEN remote file SHALL be removed (with confirmation).
6. CREDENTIALS SHALL be offered to save in OS keychain; if saved, subsequent connections SHALL auto-login.

**Independent Test**: `ftp://ftp.gnu.org/` anônimo → lista diretórios; upload/download pequeno arquivo; delete com confirmação.

---

### P1: Plugin SFTP/SSH ⭐ MVP

**User Story**: Como usuário, quero conectar via SFTP (`sftp://user@host/path`) com chave SSH ou senha, para acessar servidores modernos com segurança.

**Why P1**: SFTP é padrão atual; substitui FTP na maioria dos casos.

**Acceptance Criteria**:

1. WHEN the user types `sftp://` or `ssh://` in the panel path input THEN a login dialog SHALL appear requesting user, password, and/or private key path.
2. AFTER successful authentication THEN the panel SHALL display the remote directory listing with `[sftp]` indicator.
3. ALL FTP operations (navigation, copy, delete, mkdir) SHALL work identically over SFTP.
4. KEY-BASED auth SHALL work with `~/.ssh/id_rsa`, `id_ed25519`, etc.; passphrase prompt if key encrypted.
5. HOST key verification SHALL follow SSH known_hosts; first connection prompts to accept.

**Independent Test**: `sftp://user@localhost/` com chave → lista home; download/upload; known_hosts prompt na primeira vez.

---

### P2: Integração transparente no painel e menubar

**User Story**: Como usuário, quero que VFS paths apareçam naturalmente no painel, no histórico, e no menu `Command > VFS list`/`FTP link`/`Shell link`, sem distinção visual além do indicador `[scheme]`.

**Why P2**: Experiência unificada; MC original trata VFS como filesystem normal.

**Acceptance Criteria**:

1. THE panel path history SHALL store VFS paths and restore them on restart (via `IPathHistoryStore`).
2. THE `Command > VFS list` menu item SHALL be enabled and show active VFS connections with disconnect option.
3. THE `Command > FTP link` / `SFTP link` SHALL open a connection dialog pre-filled for new connections.
4. VFS paths SHALL work in Copy/Move dialogs as source or destination.

---

## Edge Cases

- IF FTP/SFTP connection drops during operation THEN the operation SHALL fail gracefully with error dialog offering retry/reconnect.
- IF tar archive is corrupted/incomplete THEN the plugin SHALL show error and not crash the panel.
- IF credentials are wrong THEN login dialog SHALL reappear with error message; not lock account.
- IF a VFS operation takes >30s THEN progress dialog SHALL show with Cancel option.
- IF the user copies between two different VFS (FTP → SFTP) THEN the system SHALL stream through local temp (download then upload).
- IF the tar archive contains symlinks THEN they SHALL be displayed but not followed (read-only archive).
- CONCURRENT VFS connections to same host SHALL share connection pool (per plugin).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| VFS-01 | P1: Arquitetura + Tar | Specify | Pending |
| VFS-02 | P1: Arquitetura + Tar | Specify | Pending |
| VFS-03 | P1: Arquitetura + Tar | Specify | Pending |
| VFS-04 | P1: Arquitetura + Tar | Specify | Pending |
| VFS-05 | P1: Arquitetura + Tar | Specify | Pending |
| VFS-06 | P1: Arquitetura + Tar | Specify | Pending |
| VFS-07 | P1: FTP | Specify | Pending |
| VFS-08 | P1: FTP | Specify | Pending |
| VFS-09 | P1: FTP | Specify | Pending |
| VFS-10 | P1: FTP | Specify | Pending |
| VFS-11 | P1: FTP | Specify | Pending |
| VFS-12 | P1: FTP | Specify | Pending |
| VFS-13 | P1: SFTP | Specify | Pending |
| VFS-14 | P1: SFTP | Specify | Pending |
| VFS-15 | P1: SFTP | Specify | Pending |
| VFS-16 | P1: SFTP | Specify | Pending |
| VFS-17 | P1: SFTP | Specify | Pending |
| VFS-18 | P2: Integração | Specify | Pending |
| VFS-19 | P2: Integração | Specify | Pending |
| VFS-20 | P2: Integração | Specify | Pending |
| VFS-21 | P2: Integração | Specify | Pending |

**ID format:** `VFS-NN` (VFS)
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 21 total, 0 mapped to tasks, 21 unmapped ⚠️ (mapeamento acontece na fase Design/Tasks)

---

## Success Criteria

- [ ] `tar://` navegação read-only funcional: Enter entra, lista, F3/View, F5/Copy extrai, Backspace sai.
- [ ] `ftp://` login anônimo/usuário; lista, upload, download, delete, mkdir; credenciais no keychain.
- [ ] `sftp://` login senha/chave; known_hosts; todas operações FTP equivalentes.
- [ ] Painel mostra indicador `[tar]`/`[ftp]`/`[sftp]`; histórico persiste VFS paths.
- [ ] Menu `Command > VFS list`/`FTP link`/`SFTP link` habilitados e funcionais.
- [ ] Suite de testes existente (236) continua passando; novos testes: unit VFS plugins (mock servers), integração painel.
- [ ] Build com `-warnaserror` limpo.