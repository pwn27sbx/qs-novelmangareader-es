# Feature: Fuentes en ESPAÑOL (manga/manhwa)

- **Estado**: EN CURSO — F1+F2+F4 hechas; pendiente F3/F5
- **Plan**: `~/Documents/Plans/2026-10-11-plan-fuentes-es-contenido-qs-novelmangareader.md`
- **Principio rector**: *"No se puede" no es respuesta — la solución siempre existe.*

## Objetivo
Que el lector muestre **siempre** manga/manhwa en español cuando exista:
cadena `MangaDex → InManga → zonatmo → zonatmo_org`, con aviso claro `no_spanish` si ninguna tiene ES.

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
- [ ] **F3**: aviso UI claro.
- [x] **F4**: implementar `zonatmo.org` (opción B) → **opción (C) final** + mirrors/failover + detección de dominio muerto.
- [ ] **F5**: smoke real + lint + **0 QML errors**.

## Tareas
- [x] **F0** — Validar fuentes ES
- [x] **F1** — Provider (`scripts/zonatmo_source.py`)
- [x] **F2** — Cadena (`manga_chain.py`)
- [ ] **F3** — UI
- [x] **F4** — Resiliencia (`zonatmo.org` opción B + mirrors)
- [ ] **F5** — Verificación

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
- **Tests**: `python3 -m unittest discover -s tests -p "test_*.py"` → 131 OK (2 skipped).

## Entrega
1 commit por work-unit (Conventional Commits). Push/PR = decisión del dueño.
