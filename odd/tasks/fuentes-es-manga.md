# Feature: Fuentes en ESPAÑOL (manga/manhwa)

> **Estado: CULMINADO (2026-10-25)** — F1–F5 cerradas; 5 fuentes ES en la cadena. Commits: `2f505f0`, `3da4d1e`, `edb2fb5`, `9ed918f`, `6409a2e` (ManhwaWeb).

- **Estado**: CERRADO — F0..F5 hechas (F3/F5 + R3-001 en esta pasada)
- **Plan**: `~/Documents/ObsidianVault/QS NovelMangaReader/2026-10-11-plan-fuentes-es-contenido-qs-novelmangareader.md`
- **Principio rector**: *"No se puede" no es respuesta — la solución siempre existe.*

## Objetivo
Que el lector muestre **siempre** manga/manhwa en español cuando exista:
cadena `MangaDex → InManga → zonatmo → zonatmo_org → manhwaweb`, con aviso claro `no_spanish` si ninguna tiene ES.

## Problema
MangaDex filtra `availableTranslatedLanguage[] = es-la/es` y los **manhwa** (Solo Leveling)
no tienen `es-la`; InManga no tiene manhwa. Los sitios ES clásicos (TMO/ZonaTMO/VisorTMO)
fueron **desmantelados por la policía española (mar–abr 2026)**.

## Alcance
- Provider nuevo `scripts/zonatmo_source.py` (contrato `search/latest/hot/info/pages`).
- Provider nuevo `scripts/zonatmo_org_source.py` (opción B, segundo backend).
- `manga_chain.py`: `_MODULES`, `active_chain()`, `_FORCED`, mirrors/failover.
- Fixtures + tests deterministas (RED → GREEN).
- UI: aviso `no_spanish` claro.
- Resiliencia: mirrors/failover + detección de dominio muerto.

## Decisión del dueño (cerrada)
- F1+F2 → opción (A): **zonatmo.net** (API JSON).  ← hecho
- F4 → opción (B): **zonatmo.org** (HTML) → opción (C) final (dos backends).  ← hecho

## Criterios de aceptación
- [x] **F0**: ≥ 2 fuentes ES validadas (200 + español + encuentra "Solo Leveling" + páginas sin JS).
- [x] **F1**: provider con contrato idéntico + fixtures + tests verdes (`scripts/zonatmo_source.py`).
- [x] **F2**: cadena actualizada y fall-through probado (`manga_chain.py`).
- [x] **F3**: aviso UI claro.
- [x] **F4**: implementar `zonatmo.org` (opción B) → **opción (C) final** + mirrors/failover + detección de dominio muerto.
- [x] **F5**: smoke real + lint + **0 QML errors**.

## Tareas
- [x] **F0** — Validar fuentes ES
- [x] **F1** — Provider (`scripts/zonatmo_source.py`)
- [x] **F2** — Cadena (`manga_chain.py`)
- [x] **F3** — UI
- [x] **F4** — Resiliencia (`zonatmo.org` opción B + mirrors)
- [x] **F5** — Verificación

## Progreso / evidencia
- **F1**: endpoints verificados en vivo (2026-10-11). Fixtures reales en
  `tests/fixtures/zonatmo/` (search, list, detail, chapters, reader). Tests
  `tests/test_zonatmo_source.py` (RED → GREEN). Ids = slug del manga; capítulo =
  `<manga-slug>/<chapter-slug>`.
- **F2**: `active_chain()` ES = `["mangadex","inmanga","zonatmo"]`; `_FORCED` +=
  `zonatmo`. `tests/test_manga_chain.py` (cadena de 3 + fall-through + forced).
- **F4 (opción B → C)**: `scripts/zonatmo_org_source.py` (segundo backend, HTML +
  suggest JSON). Endpoints verificados: `/api/search/suggest?q=`, `/biblioteca?page=N`,
  `/library/<tipo>/<id>/<slug>`, `/view_uploads/<id>`; imágenes
  `storage.zonatmo.org/chapters/<uploadId>/<n>.webp`. Fixtures reales en
  `tests/fixtures/zonatmo_org/` (suggest, biblioteca, series, chapter). La página de
  serie parte los capítulos en `#chapters-list` + `#chapters-hidden` → se parsean ambos
  (204 caps). Ids: serie = ruta `library/<tipo>/<id>/<slug>`, capítulo = uploadId.
  Tests `tests/test_zonatmo_org_source.py` (17, RED → GREEN).
- **F4 mirrors/failover**: cadena de 4 `["mangadex","inmanga","zonatmo","zonatmo_org"]`;
  `_MODULES` + `_FORCED` += `zonatmo_org`; `SOURCE_MIRRORS` documenta net/org. La cadena
  ahora **salta una fuente que lanza** (dominio muerto) en search/latest/hot/info en vez
  de romper la UI; cada provider cachea negativo un dominio caído.
- **F4 fixes del review (WARNING)**: `zonatmo_source.py` — eviction de cache expirado,
  señalización de truncado (`truncated` + `warnings.warn`) y retry de 5xx (no solo 429).
- **Smoke real**: (net) search "Solo Leveling" → info 202 caps → pages (HTTP 200 image/webp);
  (org) search → info 204 caps → páginas 38 → imagen HTTP 200 image/webp; cadena forzada
  `zonatmo_org` ida y vuelta OK.
- **Tests**: `python3 -m unittest discover -s tests -p "test_*.py"` → 136 OK (2 skipped);
  `node --test` → 32 OK (i18n + lints).

## F3 — aviso `no_spanish` claro
- `manga_chain.spanish_sources()` = fuentes ES sin WeebCentral (el fallback EN).
- `manga_server.py` adjunta `sourcesTried` cuando la cadena no tiene ES (con o sin
  fallback a inglés) y `notice="no_spanish"`.
- `services/Manga.qml` expone `notice`, `sourcesTried`, `detailTitle`.
- `modules/manga/components/DetailView.qml`: banner con el mensaje + "Fuentes
  consultadas: …" + botón "Buscar en otras fuentes" (emite
  `searchOtherSourcesRequested`); `MangaReader.qml` vuelve a Explorar y re-busca el título.
- Texto 100% por i18n: claves en inglés en el código + entradas es/en
  (`manga.noSpanishNotice`, `manga.sourcesTried`, `manga.searchOtherSources`) y etiquetas
  de fuente vía `I18n.tSource(id)` (mapa `sources` en `services/i18n.js`). Cero strings
  visibles hardcodeados (`lint-i18n` OK).
- Smoke real (backend en vivo): id MangaDex sin `es-la` →
  `notice=no_spanish, language=en, sourcesTried=[mangadex,inmanga,zonatmo,zonatmo_org]`;
  y un caso sin fallback → `error="Sin capítulos en español"` con `sourcesTried`.
- **Nota**: el módulo novel no tiene concepto `no_spanish` (sus fuentes ya son ES), así
  que el patrón no aplica ahí.

## F5 — verificación final
- `node tools/lint-style.js` → OK (37 archivos, 0 tokens crudos).
- `node tools/lint-i18n.js` → OK (0 literales crudos, 0 claves desconocidas).
- App reiniciada (`qs-novelmangareader stop` + start) y panel manga abierto → **0 QML
  errors** (solo WARN preexistentes de FileView/portal).
- Suite Python 136 OK (2 skipped); `node --test` 32 OK.

## R3-001 — tests de transporte del provider org
- `tests/test_zonatmo_org_source.py::TransportTest`: retry 5xx→éxito, 4xx sin retry,
  fallo de conexión marca dominio muerto + fast-fail sin tocar el transporte, y
  recuperación al expirar el TTL negativo. Transporte falso, sin red.

## Entrega
1 commit por work-unit (Conventional Commits). Push/PR = decisión del dueño.

---

## F5 — ManhwaWeb (`manhwaweb.com`) como quinta fuente (2026-10-25)

Pedido del dueño: lee manhwas en `manhwaweb.com` y ese catálogo no está en MangaDex ni en
InManga. Se añade como fuente ES propia, **al final de la cadena** (último recurso, catálogo +18).

- **El sitio es una SPA (Vite) sin HTML útil**: el contenido sale de su API JSON
  `https://api.manhwaweb.com`, leída del bundle y verificada en vivo:
  - `GET /manhwa/library?buscar=<q>&estado=&tipo=&erotico=&demografia=&order_item=alfabetic&page=<0-based>`
    → `{"data":[item],"next":bool}`. `order_item` se acepta pero **se ignora** (popular, nuevos y
    alfabetic devuelven la misma página), así que `latest()` y `hot()` comparten el listado por defecto.
  - `GET /manhwa/see/<manga id>` → serie + `chapters[]` (`chapter`, `link` del lector, `create`).
  - `GET /chapters/see/<manga id>-<label>` → `chapter.img[]` (páginas).
- **Ids**: el capítulo necesita las dos mitades, así que el id interno es `<manga id>-<label>`
  (`1_01`, `151.5_01`). El id de manga puede llevar guiones (`jibakusha-the-earthbound_…`), por eso
  el label se reconoce **desde el final** con regex.
- **Imágenes**: `img1mw.xyz` responde **403 sin Referer** y 200 con `https://manhwaweb.com/`
  (probado). Por eso `map_*` devuelve URLs del proxy del app y `manga_server.image_headers()`
  añade el `Referer` por host (`IMAGE_REFERERS`), sin tocar los demás hosts.
- **Archivos**: `scripts/manhwaweb_source.py`, `scripts/manga_chain.py` (`_MODULES`, `_FORCED`,
  cadena), `scripts/manga_server.py` (`IMAGE_REFERERS` + `image_headers`), `services/i18n.js`
  (etiqueta `tSource`), `README.md`.
- **Tests**: `tests/test_manhwaweb_source.py` (13, con fixtures reales search/info/chapter) y dos de
  `tests/test_manga_proxy.py` para el referer. En vivo: search → `manhwaweb:glory_hole_…`
  («La Tienda del Placer»), `info` 152 capítulos, `pages` 7 imágenes, y la imagen a través del proxy
  devuelve 412 KB `image/jpeg`.
- **Anomalía conocida**: las filas del listado traen categorías como **ids numéricos**, no nombres;
  `map_item` deja `tags` vacío (la tarjeta no las muestra) y los nombres salen en `info`.
- **No verificado**: el clic real en la UI (buscar en el panel y leer un capítulo), pendiente de QA
  humana; y el proxy del servidor arrancado aparte (se probó `_raw_get`, que es lo que usa).
