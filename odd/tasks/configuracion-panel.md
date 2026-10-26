# qs-novelmangareader-es — Panel de configuración (Parte 2)

| Campo | Valor |
|---|---|
| Feature ID | `configuracion-panel` |
| Rama | `i18n-es` |
| Inicio | 2026-10-25 |
| Estado | **Completo** — pendiente solo la prueba de clic del dueño |
| Plan | `~/Documents/ObsidianVault/QS NovelMangaReader/2026-10-25-finish/2026-10-25-parte-2-configuracion.md` |

## Objetivo

Un engranaje en el header de los tres paneles que abre una vista de ajustes con **velocidad de
scroll** y **idioma de la interfaz**, aplicados en vivo y persistidos — y, de paso, un solo escritor
de `settings.json` para que las dos claves no puedan pisarse.

## Decisiones

- **D1 — Un solo escritor.** `services/UiPrefs.qml` es el único que escribe el archivo;
  `services/I18n.qml` deja de tener `FileView` de escritura y delega en `UiPrefs.setLanguage()`.
  `I18n` pasa a leer `UiPrefs.language` (binding) en vez de su propia copia: si solo se quitaba el
  escritor, `lang` se quedaba congelado (lo señaló el verificador).
- **D2 — Vista, no popup.** `qs.Ui.PopupCard`/`KeyboardPanel` exigen `bar` + `anchorItem`; los paneles
  son layer-shell sin barra. Se usa el patrón de los plugins de Omarchy: página hermana en el
  `StackLayout` + flecha de volver.
- **D3 — Controles.** `PanelSlider` (**0,5..5 en pasos de 0,1**, guarda en `released`) para el scroll;
  `Toggle` etiquetado para el idioma (fila booleana con foco y Enter/Espacio, no por el borde).
  El slider **no** es operable por teclado (el componente no expone foco/teclas).
- **D4 — Alcance.** Solo claves que ya existen y se aplican en QML. Idioma de contenido
  (`QS_CONTENT_LANG`) y fuente de manga (`QS_MANGA_SOURCE`) son entorno de los backends: exponerlos
  exige reiniciar el servidor y queda como fase siguiente.
- **D5 — Glifo.** `󰒓` (el mismo que usa un plugin del dueño), no `⚙`, que no está verificado en la fuente.

## Archivos

`components/PanelSettings.qml` (nuevo), `components/PanelHeader.qml`, `modules/{anime,manga,novel}/**`,
`services/{UiPrefs,I18n}.qml`, `services/prefs.js`, `services/i18n.js`, `services/{Anime,Manga,Novel}.qml`
(limpieza de `.save()`), `tests/prefs.test.js`, `README.md`.

## Verificación

- `node --test` **57/57** (2 nuevos de `withSetting`) · python 191 · `lint-i18n` y `lint-style` OK.
- Escala ajustada tras medirla con el dueño: **0,5..5 con pasos 0,1** (1 = 120 px/muesca, 5 ≈ 1,3 muescas por
  página; 10 saltaba más de una página). Redondeo a un decimal al guardar.
- Persistencia probada en QML con un `settings.json` temporal: `0.5` se lee como `0.5`, `1.24` se guarda `1.2`,
  `0.2` se recorta a `0.5`, y `language: en`
  → el archivo queda con **las dos** claves (`{"language":"en","scrollFactor":5}`) y `I18n.lang` sigue el
  cambio en vivo.
- Vista de ajustes capturada (probe) y engranaje visible en el header real del panel de manga.
- **Bug encontrado de paso:** los cuatro `FileView.save()` del repo no existen en Quickshell 0.3.2
  (`TypeError: Property 'save' ... is not a function`); `setText()` ya escribe. Se quitaron las cuatro
  llamadas y el log quedó sin esos errores.
- **No verificado:** el clic real en el engranaje y el arrastre del slider (no puedo sintetizar clics);
  queda en la QA del dueño.
