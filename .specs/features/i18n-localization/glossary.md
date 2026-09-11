# i18n Translation Glossary

Shared term list for pt-BR / pt-PT / es, built from the actual English strings found
across `Sources/MCGuiUI`, `Sources/MCGuiApp`, `Sources/MCGuiMacOS` (dialogs, menus,
button bar, viewer/editor chrome, error messages). Every later translation task
(T6-T24) MUST reuse this table for these terms instead of choosing its own wording -
this is what keeps pt-BR/pt-PT/es consistent across files done as separate tasks.

**How to read it**: the `Diverges?` column flags terms where pt-BR and pt-PT are
genuinely different words (not the same text reused twice) - per spec.md's
confirmed requirement that PT-BR/PT-PT be real, distinct translations.

---

## File operations

| English | pt-BR | pt-PT | es | Diverges? |
| --- | --- | --- | --- | --- |
| File | arquivo | ficheiro | archivo | yes (arquivo/ficheiro) |
| Folder | pasta | pasta | carpeta | no |
| New Folder | Nova Pasta | Nova Pasta | Nueva Carpeta | no |
| Copy | Copiar | Copiar | Copiar | no |
| Move | Mover | Mover | Mover | no |
| Move / Rename | Mover / Renomear | Mover / Mudar o Nome | Mover / Renombrar | yes (Renomear/Mudar o Nome) |
| Rename | Renomear | Mudar o Nome | Renombrar | yes |
| Delete | Excluir | Eliminar | Eliminar | yes (Excluir/Eliminar) |
| Move to Trash | Mover para a Lixeira | Mover para o Lixo | Mover a la Papelera | yes (Lixeira/Lixo) |
| Overwrite | Substituir | Substituir | Sobrescribir | no |
| Skip | Ignorar | Ignorar | Omitir | no |
| Rename (conflict action) | Renomear | Mudar o Nome | Renombrar | yes |
| Already exists | Já existe | Já existe | Ya existe | no |
| Source | Origem | Origem | Origen | no |
| Destination | Destino | Destino | Destino | no |
| Path | Caminho | Caminho | Ruta | no |
| Selection | Seleção | Seleção | Selección | no |
| Select All | Selecionar Tudo | Selecionar Tudo | Seleccionar Todo | no |
| Toggle selection | Alternar Seleção | Alternar Seleção | Alternar Selección | no |
| Preserve attributes | Preservar Atributos | Preservar Atributos | Preservar Atributos | no |
| Follow symlinks | Seguir Links Simbólicos | Seguir Ligações Simbólicas | Seguir Enlaces Simbólicos | yes (links/ligações) |
| Update only | Apenas Atualizar | Apenas Atualizar | Solo Actualizar | no |
| Shell pattern | Padrão de Shell | Padrão de Shell | Patrón de Shell | no |
| Background (run in background) | Segundo Plano | Segundo Plano | Segundo Plano | no |

## Dialog buttons / common actions

| English | pt-BR | pt-PT | es | Diverges? |
| --- | --- | --- | --- | --- |
| Cancel | Cancelar | Cancelar | Cancelar | no |
| OK | OK | OK | Aceptar | no (pt) |
| Confirm | Confirmar | Confirmar | Confirmar | no |
| Save | Salvar | Guardar | Guardar | yes (Salvar/Guardar) |
| Options | Opções | Opções | Opciones | no |
| Search | Pesquisar | Pesquisar | Buscar | no |
| Find | Localizar | Localizar | Buscar | no |
| Find Next | Localizar Próximo | Localizar Seguinte | Buscar Siguiente | yes (Próximo/Seguinte) |
| Replace | Substituir | Substituir | Reemplazar | no |
| Replace All | Substituir Tudo | Substituir Tudo | Reemplazar Todo | no |
| Add | Adicionar | Adicionar | Añadir | no |
| Remove | Remover | Remover | Quitar | no (pt) |
| Undo | Desfazer | Desfazer | Deshacer | no |
| Redo | Refazer | Refazer | Rehacer | no |
| Cut | Recortar | Cortar | Cortar | yes (Recortar/Cortar) |
| Paste | Colar | Colar | Pegar | no |
| Refresh / Rescan | Atualizar | Atualizar | Actualizar | no |

## Navigation / chrome

| English | pt-BR | pt-PT | es | Diverges? |
| --- | --- | --- | --- | --- |
| Left | Esquerda | Esquerda | Izquierda | no |
| Right | Direita | Direita | Derecha | no |
| Back | Voltar | Retroceder | Atrás | yes (Voltar/Retroceder) |
| Forward | Avançar | Avançar | Adelante | no |
| Go | Ir | Ir | Ir | no |
| Parent directory | Diretório Pai | Diretório Superior | Directorio Superior | yes (Pai/Superior) |
| Window | Janela | Janela | Ventana | no |
| Sort by Name | Ordenar por Nome | Ordenar por Nome | Ordenar por Nombre | no |
| Sort by Size | Ordenar por Tamanho | Ordenar por Tamanho | Ordenar por Tamaño | no |
| Sort by Date | Ordenar por Data | Ordenar por Data | Ordenar por Fecha | no |
| Sort by Type | Ordenar por Tipo | Ordenar por Tipo | Ordenar por Tipo | no |
| Show Hidden Files | Mostrar Arquivos Ocultos | Mostrar Ficheiros Ocultos | Mostrar Archivos Ocultos | yes (Arquivos/Ficheiros) |
| Toggle Hidden Files | Alternar Arquivos Ocultos | Alternar Ficheiros Ocultos | Alternar Archivos Ocultos | yes |
| Panel Shortcuts / Keyboard Shortcuts | Atalhos | Atalhos | Atajos | no |
| Volumes | Volumes | Volumes | Volúmenes | no |

## Windows / features

| English | pt-BR | pt-PT | es | Diverges? |
| --- | --- | --- | --- | --- |
| Help | Ajuda | Ajuda | Ayuda | no |
| Bookmarks | Favoritos | Marcadores | Marcadores | yes (Favoritos/Marcadores) |
| Remove Bookmark | Remover Favorito | Remover Marcador | Quitar Marcador | yes |
| User Menu | Menu do Usuário | Menu do Utilizador | Menú de Usuario | yes (Usuário/Utilizador) |
| Viewer | Visualizador | Visualizador | Visor | no |
| Editor | Editor | Editor | Editor | no |
| View (native menu) | Visualizar | Ver | Ver | yes (Visualizar/Ver) |
| Edit (native menu) | Editar | Editar | Editar | no |
| Quit | Sair | Sair | Salir | no |
| Theme | Tema | Tema | Tema | no |
| Light | Claro | Claro | Claro | no |
| Dark | Escuro | Escuro | Oscuro | no |
| Follow System | Seguir o Sistema | Seguir o Sistema | Seguir el Sistema | no |
| Mode | Modo | Modo | Modo | no |

## Progress dialog

| English | pt-BR | pt-PT | es | Diverges? |
| --- | --- | --- | --- | --- |
| Copying… | Copiando… | A copiar… | Copiando… | yes (gerund vs. "a + infinitive") |
| Moving… | Movendo… | A mover… | Moviendo… | yes |
| Scanning… | Analisando… | A analisar… | Analizando… | yes |
| Loading… | Carregando… | A carregar… | Cargando… | yes |
| File %1$d of %2$d | Arquivo %1$d de %2$d | Ficheiro %1$d de %2$d | Archivo %1$d de %2$d | yes (arquivo/ficheiro) |
| ETA / time remaining | Tempo Restante | Tempo Restante | Tiempo Restante | no |
| Size | Tamanho | Tamanho | Tamaño | no |

## Error messages (`FileSystemServiceError`, T5)

| English | pt-BR | pt-PT | es | Diverges? |
| --- | --- | --- | --- | --- |
| Permission denied | Permissão Negada | Permissão Negada | Permiso Denegado | no |
| Already exists | Já Existe | Já Existe | Ya Existe | no |
| In use / File in use | Em Uso | Em Uso | En Uso | no |
| Insufficient disk space | Espaço em Disco Insuficiente | Espaço em Disco Insuficiente | Espacio en Disco Insuficiente | no |
| Volume disconnected | Volume Desconectado | Volume Desligado | Volumen Desconectado | yes (Desconectado/Desligado) |
| Path too long | Caminho Muito Longo | Caminho Demasiado Longo | Ruta Demasiado Larga | yes (Muito/Demasiado) |

---

**Note on "Trash"**: macOS's own PT-BR system localization uses "Lixeira"; its PT-PT
localization uses "Lixo". Followed here for consistency with the OS chrome the user
already sees.

**Note on formal register**: pt-PT strings favor the OS's own formal-neutral register
("Mudar o Nome" rather than a BR-style verb-first casual form); pt-BR strings match
macOS's own PT-BR localization conventions (e.g. "Renomear", "Salvar", "Excluir").
Spanish is one neutral/international variant (no `es-ES`/`es-MX` split), per spec.md's
confirmed assumption.
