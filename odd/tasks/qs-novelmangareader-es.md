# qs-novelmangareader-es — Localización al español (anime + manga)

| Campo | Valor |
|---|---|
| Feature ID | `qs-novelmangareader-es` |
| Rama | `i18n-es` (base `upstream/master` = `c3ebeca776af7b8baddc08f6c490df6429f9869e`) |
| Repo de trabajo | `~/Projects/forks/qs-novelmangareader-es` |
| Upstream | `dhrruvsharma/qs-novelmangareader` (GPL-3.0) |
| Inicio | 2026-10-11 |
| Estado | **Fase 1 completa + fix WU-6b** · GATE §15.1 cerrado |
| Plan fuente | `2026-10-11-plan-localizacion-es-qs-novelmangareader.md` (§0–§16) |
| Handoff | `2026-10-11-handoff-orquestador-qs-novelmangareader-es.md` |

> El plan es la **fuente de verdad técnica**; el handoff, la **operativa**. Donde haya conflicto, manda el plan.

---

## Objetivo

Tener la interfaz de la app Quickshell `qs-novelmangareader` **en español latinoamericano neutro**, instalable y usable, sin romper bibliotecas, keybinds ni el flujo funcional existente, y **prefiriendo contenido en español cuando la fuente ya lo ofrece** (subtítulos multi-idioma en anime; MangaDex `es-la` en manga).

## Problema / Por qué

- El proyecto original está 100% en inglés y sin ninguna infraestructura de i18n (`0` usos de `qsTr`, `0` `.ts`/`.qm`).
- Rehacer desde cero duplicaría el mantenimiento de la parte frágil y costosa (los scrapers Python) y no aportaría valor frente a la UI QML ya resuelta.
- Lo que se consume es el **contenido**; una UI traducida con todo el contenido en inglés entrega poco valor → el alcance incluye preferir el contenido en español donde la fuente lo permita.

## Alcance

**Incluye**
- Etiquetas de UI, botones, pestañas, filtros, tooltips, placeholders.
- Mensajes de estado, carga y error de la UI.
- Estados vacíos de las tres bibliotecas.
- Mensajes del instalador y `--help` del CLI.
- Preferir contenido en español cuando la fuente lo sirva (subtítulos anime; MangaDex `es-la`).

**Excluye**
- Contenido scrapeado sin versión en español (no se *fabrica* traducción).
- Sustítulos de anime que la fuente no tenga en español (ASR+MT = otro proyecto).
- Nombres de fuentes (`FreeWebNovel`, `NovelBin`), tokens de comando (`anime`, `manga`, `novel`, `start`, `stop`, `log`), `sub`/`dub`, `Manga`/`Manhwa`/`Manhua`, `mpv`, fuentes tipográficas, logs internos.
- Novelas en español (F1.5-3): fuera de alcance por ahora.

## Constraints

- **GPL-3.0**: preservar licencia y avisos; fork privado de uso personal (sin publicar → sin obligación de distribución, pero se mantiene la licencia).
- **Datos del dueño**: nunca probar contra `~/.local/share/quickshell/*library.json` ni `~/.local/share/quickshell-{manga,novel}`. Usar `HOME`/`XDG_DATA_HOME` temporal. Respaldar y listar antes/después de cualquier prueba en vivo.
- **config-sync**: no editar `~/.config/hypr/` ni `/usr/share/omarchy/`. Los keybinds/autostart (§15.3) los aplica el dueño.
- **Wayland/Quickshell**: i18n por singleton QML (`pragma Singleton` + `Singleton {}` + `import qs.services`), **sin `qmldir`**.
- **Sin `wtype`** para pruebas en vivo.
- **Commits**: Conventional Commits, **sin atribución de IA**; uno por work-unit en `i18n-es`.
- **RDD**: off hasta que el dueño lo habilite.

## Decisiones cerradas (GATE §15.1)

| ID | Decisión |
|---|---|
| **D-ES** | Español latinoamericano neutro, con **«tú»** (no vos, no usted); vocabulario latino («video», no «vídeo»). |
| **D-FORK** | Fork **privado/local**. Sin `origin` en GitHub; remoto único `upstream` = `dhrruvsharma/qs-novelmangareader`. Rama `i18n-es`. |
| **D-MODULES** | Uso real: **anime + manga**. **Novelas NO se usan** → WU-4 diferido al final (omitible si el dueño lo confirma). |
| **D-MANGA** | Fuente de manga por defecto: **MangaDex `es-la`** con idioma `es`; **WeebCentral `en`** con idioma `en`. |

---

## Decisiones de implementación (registradas por WU)

- **WU-1 — núcleo i18n en JS puro.** Las tablas y `t()`/`tn()` viven en `services/i18n.js` (JS puro, sin QML); `services/I18n.qml` es un wrapper delgado (`lang`, `t`, `tn`). Motivo: test unitario determinista con `node --test`, sin sesión Wayland (§15.7). El plan D2 ponía las tablas dentro del singleton; se extraen por testabilidad, conservando la intención (clave en inglés, tabla central, interpolación, sin `qmldir`). El singleton **no** importa `qs.services` (§14.3).
- **WU-1 — comando de tests canónico:** `node --test` (auto-descubre `**/*.test.js`). `node --test tests/` (dir suelto) no funciona en Node 26.
- **WU-2 — `LoadingBar`/`PanelDecor` no tienen strings de UI.** El "more is on its way" de §6.1 es un **comentario**, no un caption → no se tocaron, no se creó la clave.
- **WU-2 — `ListElement` no admite llamadas a funciones.** Los filtros (manga/anime) usan `ListModel`: se guarda la **clave** en el rol `labelKey` y el delegate hace `text: I18n.t(labelKey)`. Los tabs de `AnimePanel` son array JS y se traducen inline (`I18n.t("tab.browse")`).
- **WU-2 — `LoadingState` default `label: ""`**: los 2 call sites pasan `label:`; se eliminó el literal inglés `"loading"` para no acoplar `components/` a `qs.services` (§14.3).
- **WU-2 — errores del backend `data.error`**: se dejan **verbatim** (EN) por §6.8/§14.1; la mejora opcional `I18n.t("error.server", …)` se descartó por ahora para no alterar la salida en EN (DoD #4).
- **WU-2 — normalización cosmética EN:** `"Ep."+n` y `"Ep. "+n` → clave única `ep` = `"Ep. %1"` (unifica "Ep.3"/"Ep. 3"). Cambio solo de un espacio; pendiente de tu OK si querés EN byte-idéntico.
- **WU-3 — chips Manga/Manhwa/Manhua:** se guardan como `labelKey` literal (p. ej. `"Manga"`) y el delegate hace `I18n.t(labelKey)`; al no existir la clave, el core devuelve la propia clave → se muestran sin traducir sin caso especial.
- **WU-3 — clave extra `manga.pageFailed`** ("no se pudo cargar"/"failed to load"): el sufijo de error por página no estaba en §6.3; se añadió para no dejar EN crudo.
- **WU-3 — `count.chapter`** corrige singular ("1 capítulo" en vez de "1 capítulos"); en EN también ("1 chapter"). Mejora intencional; notar por si querés EN byte-idéntico.
- **WU-4/WU-6b — corrección a mi nota previa (el revisor tenía razón):** `Ongoing` **SÍ se muestra** en un badge (`(modelData.status).toUpperCase()`), así que §6.4 acertaba en que es visible; pero es un **valor de dato**, no un label de filtro → se resuelve con el mapeo de datos `tData` (WU-6b), NO con una clave de filtro. `All` (`Novel.qml:21`) sigue siendo un **sentinel** de la API (no se muestra). Las claves de filtro `novel.filter.ongoing`/`novel.filter.all` siguen sin uso.
- **WU-6b — `I18n.tData(value)`**: mapea status/type conocidos (Ongoing/OnGoing→"En curso", Completed→"Completada", Hiatus→"En pausa", Cancelled→"Cancelada", Movie→"Película", Special→"Especial"; TV/OVA/ONA iguales en ambos idiomas), con **fallback al valor original** y coincidencia **case-insensitive**. Aplicado en 5 badges (anime type; manga type+status; novel status×2). Guard de test en `tests/i18n.test.js`.
- **WU-4 — wordmark "N"/"ovel"**: marca, se mantiene (igual que "A"/"nime", "M"/"anga").
- **WU-5 — lint:** `tools/lint-i18n.js` (a) falla si un prop de texto tiene literal EN crudo fuera de `I18n.t`/`tn`; (b) falla si una clave usada en QML no existe en la tabla. Se integra como `tests/lint.test.js`.
- **WU-5 — reglas del lint:** los bloques `text: { … }` se evalúan solo en su expresión `return` (evita falsos positivos por comparaciones de datos como `mode === "dub"`); las líneas con `// i18n-ignore` se saltan (wordmarks de marca). Comandos: `node --test` y `node tools/lint-i18n.js`.

> Orden de ejecución recomendado (novela diferida): `WU-0 → 1 → 2 → 3 → 5 → 6 → [7 cond.] → 8 → 9 → [10 opc.] → [4 si aplica]`.

- [x] **WU-0** — Setup: clonar fork, `upstream`, rama `i18n-es`, feature doc + espejo Engram. *(F1-1)*
- [x] **WU-1** — Núcleo i18n: `services/I18n.qml` (`pragma Singleton` + `Singleton{}`), `t()` + `tn()` (plurales), sin `qmldir`. *(F1-2, F1-7, §15.4)*
- [x] **WU-2** — Envolver comunes + anime. *(F1-3, F1-4)*
- [x] **WU-3** — Envolver manga. *(F1-5)*
- [x] **WU-5** — Lint anti-strings sin `I18n.t` + test de paridad de claves `es`↔`en`. *(F1-8)*
- [x] **WU-6** — QA visual integral (3 módulos × vistas). *(F1-9, read-only)*
- [x] **WU-6b** — Fix (revisión del orquestador): traducir **datos** status/type mostrados en badges. *(gap de WU-4/WU-6)*
- [ ] **WU-7** — Subtítulos ES (**CONDICIONADO**: requiere confirmar campo de idioma). *(F1.5-1, §13.3/§14.2)*
- [ ] **WU-8** — MangaDex ES (`es-la`), mismo contrato JSON; tests con fixtures. *(F1.5-2, §15.5)*
- [ ] **WU-9** — Instalador / CLI / README. *(F2)*
- [ ] **WU-10** — Fallback anime con `ani-cli` (`ANI_CLI_PLAYER=debug`), opcional. *(F3-2)*
- [x] **WU-4** — Envolver novela (**DIFERIDO AL FINAL**, omitible). *(F1-6)*

---

## Scope autorizado (superficies de edición por WU)

| WU | Superficies autorizadas |
|---|---|
| WU-0 | repo nuevo (git setup) + `odd/tasks/qs-novelmangareader-es.md` |
| WU-1 | `services/I18n.qml`; tests de i18n (`tests/` o `tools/`) |
| WU-2 | `components/{EmptyState,LoadingState,LoadingBar,PanelDecor}.qml`, `modules/anime/**`, `services/Anime.qml` |
| WU-3 | `modules/manga/**`, `services/Manga.qml` |
| WU-5 | `scripts/` o `tools/` (lint), `tests/` |
| WU-6 | — (read-only) |
| WU-7 | `scripts/anime_server.py` |
| WU-8 | `scripts/manga_server.py` + nuevo provider MangaDex (`scripts/`), selección de fuente |
| WU-9 | `install.sh`, `scripts/install-common.sh`, `bin/qs-novelmangareader`, `README.md` |
| WU-10 | provider de anime (`scripts/`) |
| WU-4 | `modules/novel/**`, `services/Novel.qml` |

---

## Criterios de aceptación

**Por WU**
- **WU-0**: repo clonado en `c3ebeca`, `upstream` configurado, rama `i18n-es` creada, feature doc creado y espejado en Engram. ✅
- **WU-1**: un valor carga y traduce; `t()` interpola; `tn()` resuelve singular/plural.
- **WU-2**: anime 100% en ES (tabs, filtros, detalle, estados, errores).
- **WU-3**: manga 100% en ES.
- **WU-5**: lint falla si hay literal EN crudo en `text:/label:/title:/subtitle:/placeholderText:` sin `I18n.t`; test detecta claves huérfanas.
- **WU-6**: 3 módulos × vistas sin desbordes; acentos `á é í ó ú ñ ¿ ¡` correctos.
- **WU-7**: si existe pista `es`, se elige; si no, `default` (solo si se confirma el campo de idioma).
- **WU-8**: lee capítulos `es-la` con el mismo contrato JSON; tests sin red real.
- **WU-9**: mensajes en ES; tokens de comando intactos.
- **WU-10**: si el scraper principal falla, usa `ANI_CLI_PLAYER=debug`.
- **WU-4**: novela 100% en ES (si aplica).

**Global (DoD)**
1. Con `es`: toda la UI en español.
2. Lint verde: ninguna cadena EN cruda sin `I18n.t` en las propiedades de texto.
3. `es` y `en` con el mismo conjunto de claves (sin huérfanas).
4. Con `en`: comportamiento idéntico al original (sin regresión).
5. Sin regresión funcional: scrapers, `mpv`, descargas, bibliotecas intactos.
6. F1.5 (si se hace): tests con fixtures, nunca contra la red real.

---

## Checks

| WU | Checks |
|---|---|
| WU-0 | `git remote -v`; `git branch -vv`; doc leído/espejado |
| WU-1 | carga en panel (`qs -p`); test unitario de `t`/`tn` |
| WU-2 | QA visual anime; lint parcial |
| WU-3 | QA visual manga |
| WU-5 | correr lint (verde); test de claves |
| WU-6 | recorrido completo en vivo con `XDG_DATA_HOME` temporal |
| WU-7 | gate previo: verificar campo de idioma; test con `cfg` de ejemplo |
| WU-8 | tests con fixtures JSON grabadas; contrato JSON idéntico |
| WU-9 | `--help`; instalar en `HOME` temporal |
| WU-10 | prueba con scraper principal simulado caído |
| WU-4 | QA visual novela (si aplica) |

---

## Ruta por tarea + evidencia del trigger

> Una ruta por tarea: **inline** o **delegado**. Se confirma al arrancar cada WU.

| WU | Ruta planificada | Evidencia del trigger |
|---|---|---|
| WU-0 | inline | setup mecánico + estado git (bash) + 1 archivo nuevo |
| WU-1 | inline o delegado | 1 archivo no trivial con diseño (t/tn) + test |
| WU-2 | delegado (writer) | 2+ archivos no triviales (comunes + anime) |
| WU-3 | delegado (writer) | 2+ archivos no triviales (manga) |
| WU-5 | inline o delegado | script de lint + test; 1–2 archivos nuevos |
| WU-6 | inline (read-only) | QA acotada |
| WU-7 | delegado | cambio en `anime_server.py` + test; gate previo |
| WU-8 | delegado (writer) + verificador | provider nuevo, riesgo medio (WU cambia comportamiento) |
| WU-9 | delegado (writer) | 4 archivos no triviales |
| WU-10 | delegado | provider nuevo |
| WU-4 | delegado (writer) | 2+ archivos no triviales (novela) |

---

## Forecast de líneas + estrategia de entrega

- **Forecast (heurística ODD, ~400 líneas/autor cambiadas por tarea):**
  - Fase 1 (WU-0..WU-6, sin novela): envolver ~60 strings en ~18 archivos + `I18n.qml` + lint/tests → **cerca o algo por encima de 400**.
  - WU-8 (MangaDex) empuja el total **por encima de 400**.
- **Estrategia de entrega: `ask-on-risk` (default ODD).** Al cruzar ~400 líneas del rango, preguntar **una vez** por la cadena (`stacked-to-main` o `feature-branch-chain`) y registrar los cortes aquí.
- Los WU son cortes naturales para PRs chicos y revisables.

---

## QA de Fase 1 (WU-6) — resultados

Automática (agente):
- `node --test` → **11/11** (incluye paridad `es`↔`en` y los 2 guards de lint).
- `node tools/lint-i18n.js` → **OK** (sin literales EN crudos; sin claves inexistentes).
- Carga real `qs -p <repo>` con `QS_LANG=es` y `QS_LANG=en`, togglando los 3 paneles por IPC (`animePlayer`/`mangaReader`/`novelReader`) → **sin errores de QML, binding, `undefined` ni I18n**.
- Sin procesos huérfanos tras las pruebas.
- **Paridad EN (spot-check):** los valores `en` de `manga.noPages`, `manga.invalidResponse`, `anime.noStream`, `novel.listIncomplete`, `novel.loadFailed`, `anime.library.title`, `manga.search` coinciden **verbatim** con `c3ebeca`.

Pendiente (humano): la QA **visual** real (acentos `á é í ó ú ñ ¿ ¡`, desbordes por longitud ES ~15–20% mayor, tabs/botones de ancho fijo) la debe confirmar el dueño abriendo la app. El agente no puede ver píxeles; no se declara como verificado.



| WU | Commit | Fecha | Estado |
|---|---|---|---|
| WU-0 | `eb39f81` | 2026-10-11 | ✅ completo |
| WU-1 | `3f8cdc4` | 2026-10-11 | ✅ completo |
| WU-2 | `5048592` | 2026-10-11 | ✅ completo |
| WU-3 | `84ad035` | 2026-10-11 | ✅ completo |
| WU-4 | `c4e359b` | 2026-10-11 | ✅ completo |
| WU-5 | `17eabfc` | 2026-10-11 | ✅ completo |
| WU-6 | `edf2203` | 2026-10-11 | ✅ completo |
| WU-6b | `—` (se completa al cierre) | 2026-10-11 | ✅ completo |

---

## Próximo paso

Fase 1 completa. Siguiente (con validación individual del dueño): **WU-7** (subtítulos ES, condicionado al campo de idioma §14.2), **WU-8** (MangaDex `es-la`, §15.5), **WU-9** (instalador/CLI/README), **WU-10** (ani-cli, opcional). Además: QA visual humana y ajuste de desbordes.
