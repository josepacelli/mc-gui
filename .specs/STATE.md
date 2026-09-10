# STATE

## Decisions

### AD-001
- **Decision**: Solução organizada em 3 projetos por responsabilidade — `McGui.Core` (modelos + interfaces, sem dependência de SO), `McGui.Infrastructure.<Plataforma>` (implementação real por SO, ex.: `McGui.Infrastructure.macOS`), `McGui.App` (Avalonia UI/ViewModels).
- **Reason**: O projeto tem como objetivo declarado ser um clone completo multiplataforma (Windows/macOS/Linux) do Midnight Commander, entregue primeiro em macOS. Isolar código específico de SO atrás de interfaces desde a primeira feature evita reescrever `Core`/`App` ao portar para as próximas plataformas.
- **Trade-off**: Mais projetos/arquivos de configuração para manter desde o início, comparado a um monolito de projeto único.
- **Scope**: Toda feature futura que envolva acesso a sistema de arquivos, diálogos nativos, ou qualquer API específica de SO deve seguir este padrão de camadas.
- **Date**: 2026-09-05
- **Status**: superseded by AD-002

### AD-002
- **Decision**: Migração para Swift/SwiftUI usa 1 Swift Package Manager package com 4 targets (`MCGuiApp`, `MCGuiCore`, `MCGuiUI`, `MCGuiMacOS`), substituindo a arquitetura de 3 projetos C# (Core, Infrastructure, App).
- **Reason**: Apps SwiftUI tipicamente usam single-package; limites de módulo via `public`/`internal`/`package` substituem limites de projeto. Camadas de Clean Architecture preservadas via dependências entre targets.
- **Trade-off**: Isolamento menos forçado que projetos separados; depende de disciplina do dev e do modificador `package`.
- **Scope**: Toda feature Swift futura neste repositório.
- **Date**: 2026-09-09
- **Status**: active

### AD-003
- **Decision**: Editor e viewer de texto usam `NSViewRepresentable` envolvendo `NSTextView` (TextKit 2); viewer de imagem/hex é SwiftUI puro.
- **Reason**: Nenhum editor de texto SwiftUI puro iguala capacidade do NSTextView; TextKit 2 dá syntax highlighting, large file handling, acessibilidade.
- **Trade-off**: Exige bridging AppKit; não é SwiftUI puro, mas só nos componentes de editor/viewer.
- **Scope**: Features de Editor e Viewer de texto.
- **Date**: 2026-09-09
- **Status**: active

## Handoff

- **Feature `convert-to-swift-swiftui`**: **Tasks phase DONE** — spec.md (93 requisitos, P1-P3) e design.md (Approved, AD-002/AD-003 gravados) já existiam nesta branch; nesta sessão o design foi aprovado pelo usuário e `tasks.md` foi criado: 54 tasks atômicas em 13 fases (P1: fases 1-11 = MVP completo; P2: fase 12 volume/filtro; P3: fase 13 bookmarks). `validate_tasks.py`: 0 erros, 6 warnings esperados (Tests: none em config/protocolos puros/componentes presentacionais/WindowManager pré-lógica, todos confirmados contra a Test Coverage Matrix). Todas as 93 IDs de requirement do spec mapeadas para pelo menos 1 task.
- **Next step**: Apresentar tasks.md pro usuário pra aprovação final + oferecer sub-agent delegation (54 tasks → ~8 batches de ~7 tasks cada, um worker por batch de fases consecutivas inteiras). Após aprovação, Execute começa pela Phase 1 (Package.swift + models + protocols).
- **Blockers**: none — repo ainda não tem nenhum arquivo Swift/Package.swift; código C#/Avalonia em `src/` permanece intocado (spec é reescrita completa, não migração incremental).
- **Uncommitted files**: `.specs/features/convert-to-swift-swiftui/tasks.md` (novo), `.specs/STATE.md` (AD-002/AD-003 + este handoff).
- **Branch**: `convert-to-swift-swiftui`, idêntica a `main` em commits (nenhum commit Swift ainda) — trabalho local, nada pushed.

---

### Handoff history (features anteriores nesta branch/repo, para contexto)

- **Feature `macos-native-chrome`**: DONE, pushed (`699daca`).
- **Bug fix `F1/F9/F10`**: corrigido em `56c4071` (local, não pushed) — F9/F10 agora funcionam via Click; F1 desabilitado (sem Help viewer). F2 "Menu" tem o mesmo problema mas não foi tocado (fora de escopo).
- **Feature `copy-move-mc-options`**: DONE — 10 tasks, Verifier PASS, 236 testes.
- **Feature `macos-installer`**: DONE — 4 tasks, `build-macos.sh` + GitHub Actions `build-macos.yml`, DMG em `artifacts/`.
- **Feature `viewer-f3`**: PARCIAL (6/7 tasks) — T5 (Hex mode) ainda pendente na versão C#/Avalonia; **superseded** pela reescrita Swift (a feature `convert-to-swift-swiftui` cobre hex mode nativamente em FV-04/T36).

(End of file - total 18 lines)