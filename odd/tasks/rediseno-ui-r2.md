# qs-novelmangareader-es — Rediseño UI/UX · Fase R2 (superficie + header + navegación)

| Campo | Valor |
|---|---|
| Feature ID | `rediseno-ui-r2` |
| Rama | `i18n-es` (fork privado, sin `origin`) |
| Repo de trabajo | `~/Projects/forks/qs-novelmangareader-es` |
| Inicio | 2026-10-25 |
| Estado | **Completo (R2.1–R2.8)** |
| Spec | `2026-10-11-plan-r2-header-panel-qs-novelmangareader.md` (vault) — «se implementa **esta spec**» |
| Base | Plan C (Omarchy) ✅ + R1 (tokens) ✅ + R-C1 ✅ + R-C2 ✅ |

> Alcance del plan: **header + filtros** de los 3 módulos. No se toca detalle, lector, backends ni idioma.

## Problema

El header quedó con **cajas duras**: `components/SegmentBar.qml` dibuja un contorno alrededor del grupo y
`fe4bdea`/`cfb2786` acentuaron ese borde. La spec pide lo contrario: **cero bordes**, activo **tintado**,
inactivo `muted` sin fondo. Además los filtros viven en el `BrowseView` de cada módulo con su propia copia
del control segmentado, así que el look deriva entre los tres.

## Decisiones de implementación

| ID | Decisión |
|---|---|
| **D-BORDES** | `qs.Ui.ButtonGroup` de Omarchy **4.0.6** fija `bordered: true` en su delegate: usarlo reproduce justo las cajas que la spec rechaza. Los tabs y los filtros se arman con `qs.Ui.Button` (`bordered: false`, `selected` = tinte, `foreground` = `Colors.text`/`Colors.muted`), que es el mismo primitivo y los mismos tokens de estado. **Desvío del componente nombrado, no del look.** |
| **D-COMPARTIDO** | Un solo `components/PanelHeader.qml` y un solo `components/FilterBar.qml` para los 3 módulos: la consistencia que pide §5.3 no puede depender de mantener 3 copias iguales a mano. |
| **D-RANURA** | Los filtros van en un `Flickable` horizontal: si no caben se deslizan; si caben, no se mueven (`interactive: contentWidth > width`). |
| **D-BUSQUEDA** | El campo de búsqueda sigue viviendo en cada panel (tiene debounce y lógica propios) y se coloca en el slot del header, así tabs y campo nunca se superponen. |
| **D-IDIOMA** | El chip EN/ES pasa a ser `components/LanguageToggle.qml` **sin borde** (antes era un `Button` inline duplicado en cada panel). |

## Checklist

- [x] **R2.1** — `components/FilterBar.qml`: chips tintados, sin borde, scroll-x.
- [x] **R2.2** — `components/PanelHeader.qml`: tabs tintados + acciones (buscar, modo, idioma, minimizar) y slot para el campo de búsqueda.
- [x] **R2.3** — `components/LanguageToggle.qml` sin borde (chip), usado por el header.
- [x] **R2.4** — `modules/anime/{AnimePanel,components/BrowseView}.qml` al header/filtros nuevos.
- [x] **R2.5** — `modules/manga/{MangaReader,components/BrowseView}.qml` idem (sin SUB/DUB).
- [x] **R2.6** — `modules/novel/{NovelReader,components/BrowseView}.qml` idem (sin SUB/DUB).
- [x] **R2.7** — Verificación: `node --test`, `lint-style`, `lint-i18n`, carga real de los 3 paneles, capturas.
- [x] **R2.8** — `components/SegmentBar.qml` borrado (0 consumidores).

## Scope autorizado (superficies)

`components/PanelHeader.qml`, `components/FilterBar.qml`, `components/LanguageToggle.qml`,
`components/SegmentBar.qml` (borrar), `modules/{anime,manga,novel}/**`, `odd/tasks/rediseno-ui-r2.md`.

## Criterios de aceptación

- Cero `bordered: true` en header/filtros; el estado activo es **tinte**, no caja ni relleno sólido.
- Tabs a la izquierda, acciones a la derecha, misma línea base, misma altura en los 3.
- Switch Browse/Library, búsqueda, SUB/DUB, EN/ES, minimizar y filtros funcionan igual que antes.
- Filtros con scroll horizontal cuando no caben.
- `lint-style` + `lint-i18n` + `node --test` verdes; 0 errores QML.

## Evidencia

- **Sin cajas**: 0 `bordered: true` en header/filtros; `grep -rn SegmentBar` → 0 y el componente borrado. Tabs y chips son `qs.Ui.Button` con `bordered: false`; el activo lleva `selected` (tinte de `Style`) y el texto `Colors.text`, el inactivo `Colors.muted`.
- **Un solo origen**: `components/PanelHeader.qml` + `components/FilterBar.qml` usados por anime, manga y novela (los 3 paneles y los 3 `BrowseView`). El chip de proveedor de novelas entra por `extraAction` (slot `Component` + `Loader`), así el header sigue siendo el mismo.
- **Scroll-x medido**: con 5 filtros, `contentWidth=327,25`; a 200 px → `interactive=true`, a 900 px → `interactive=false` (los chips no se mueven si caben).
- **En vivo** (capturas): anime con `Browse/Library` + `⌕` + `SUB/DUB` + `EN` + `─` y filtros `Popular/Latest/Japan/China/Korea`; manga sin SUB/DUB con `Hot/Latest/Manga/Manhwa/Manhua`; novela con el selector de proveedor entre búsqueda y EN, filtros `Hot/Latest`. Misma altura y alineación en los 3.
- **Gates**: `node --test` 44/44 · `node tools/lint-style.js` OK (38 archivos, 0 crudos) · `node tools/lint-i18n.js` OK · carga real sin errores (`Configuration Loaded`, `SMOKE … accent=#7daea3`, 0 `TypeError`/`Unable to assign` nuevos).
- **Incidente durante el trabajo**: `signal modeChanged` chocaba con el change-signal de `property string mode` (el shell del dueño mostró «Config reload failed»). Renombrado a `modeSelected`; el reload quedó limpio. Lección: un `signal X` no puede repetir el nombre de una property `x`.
- **No verificado**: el campo de búsqueda superpuesto no se ejercitó con clic (el agente no tiene `wtype`); su geometría es la misma que antes (`left` del panel → `actions.left`, ahora el slot del header). Los `PopupCard`/`PanelHero`/`PanelSeparator` del plan §R2 quedan para R3/R4, fuera de esta fase.
