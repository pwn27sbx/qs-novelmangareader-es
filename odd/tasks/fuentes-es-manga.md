# Feature: Fuentes en ESPAÑOL (manga/manhwa)

- **Estado**: EN CURSO — F1+F2 (zonatmo.net) hechas; pendiente F3/F4/F5
- **Plan**: `~/Documents/Plans/2026-10-11-plan-fuentes-es-contenido-qs-novelmangareader.md`
- **Principio rector**: *"No se puede" no es respuesta — la solución siempre existe.*

## Objetivo
Que el lector muestre **siempre** manga/manhwa en español cuando exista:
cadena `MangaDex → InManga → zonatmo`, con aviso claro `no_spanish` si ninguna tiene ES.

## Problema
MangaDex filtra `availableTranslatedLanguage[] = es-la/es` y los **manhwa** (Solo Leveling)
no tienen `es-la`; InManga no tiene manhwa. Los sitios ES clásicos (TMO/ZonaTMO/VisorTMO)
fueron **desmantelados por la policía española (mar–abr 2026)**.

## Alcance
- Provider nuevo `scripts/zonatmo_source.py` (contrato `search/latest/hot/info/pages`).
- `manga_chain.py`: `_MODULES`, `active_chain()`, `_FORCED`.
- Fixtures + tests deterministas (RED → GREEN).
- UI: aviso `no_spanish` claro.
- Resiliencia: mirrors/failover + detección de dominio muerto.

## Decisión del dueño (cerrada)
- F1+F2 → opción (A): **zonatmo.net** (API JSON).  ← hecho
- F4 → opción (B): **zonatmo.org** (HTML) → opción (C) final (dos backends).

## Criterios de aceptación
- [x] **F0**: ≥ 2 fuentes ES validadas (200 + español + encuentra "Solo Leveling" + páginas sin JS).
- [x] **F1**: provider con contrato idéntico + fixtures + tests verdes (`scripts/zonatmo_source.py`).
- [x] **F2**: cadena actualizada y fall-through probado (`manga_chain.py`).
- [ ] **F3**: aviso UI claro.
- [ ] **F4**: implementar `zonatmo.org` (opción B) → **opción (C) final** + mirrors/failover + detección de dominio muerto.
- [ ] **F5**: smoke real + lint + **0 QML errors**.

## Tareas
- [x] **F0** — Validar fuentes ES
- [x] **F1** — Provider (`scripts/zonatmo_source.py`)
- [x] **F2** — Cadena (`manga_chain.py`)
- [ ] **F3** — UI
- [ ] **F4** — Resiliencia (`zonatmo.org` opción B + mirrors)
- [ ] **F5** — Verificación

## Progreso / evidencia
- **F1**: endpoints verificados en vivo (2026-10-11). Fixtures reales en
  `tests/fixtures/zonatmo/` (search, list, detail, chapters, reader). Tests
  `tests/test_zonatmo_source.py` (RED → GREEN). Ids = slug del manga; capítulo =
  `<manga-slug>/<chapter-slug>`.
- **F2**: `active_chain()` ES = `["mangadex","inmanga","zonatmo"]`; `_FORCED` +=
  `zonatmo`. `tests/test_manga_chain.py` (cadena de 3 + fall-through + forced).
- **Smoke real**: search "Solo Leveling" → info (202 caps) → pages (12 imgs, HTTP 200
  image/webp). `latest()`/`hot()` usan el orden por defecto del listing (la API ignora
  `order`/`sort`).
- **Tests**: `python3 -m unittest discover -s tests -p "test_*.py"` → 100 OK (2 skipped).

## Entrega
1 commit por work-unit (Conventional Commits). Push/PR = decisión del dueño.
