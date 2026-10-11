# qs-novelmangareader-es — Rediseño UI/UX · Fase R1 (Fundaciones)

| Campo | Valor |
|---|---|
| Feature ID | `rediseno-ui-r1` |
| Rama | `i18n-es` (rama de trabajo del fork; sin `origin`) |
| Repo de trabajo | `~/Projects/forks/qs-novelmangareader-es` |
| Inicio | 2026-10-11 |
| Estado | **En curso** |
| Plan fuente | `/home/pwnsxb/Documents/Plans/2026-10-11-plan-rediseno-ui-qs-novelmangareader.md` (§7 R1, §9 cobertura) |
| Review fuente | `/home/pwnsxb/Documents/Plans/2026-10-11-review-qs-novelmangareader-es.md` |

> Capa **visual + navegación**. NO se tocan backends ni datos (`scripts/`, `services/{Anime,Manga,Novel,Http,HealthPoller}.qml` lógica, `~/.local/share/quickshell*`).

---

## Objetivo

Unificar la UI sobre un **sistema de tokens** (`qs.Commons.Style`) espejo de Omarchy, eliminando todos los radios/espaciados crudos, unificando superficies/estados y motion, para que la app "se sienta parte del escritorio".

## Problema / Por qué

- **No hay sistema de tokens**: 18 valores distintos de `radius:` a mano; `services/DesktopTheme.qml` es un no-op (`rad(n) = n`).
- Evidencia medida: **82** literales `radius:` crudos · 16 usos `DesktopTheme.rad(...)` · **124** `duration:` crudos.
- Mezcla de familias (Noto Sans/Serif) sin escala clara; estados hover/selected dispares por archivo.

## Decisión cerrada

| ID | Decisión |
|---|---|
| **D-ESPEJO** | **(A) Espejo propio** (`<app>/Commons/Style.qml`), NO symlink ni import de Omarchy. Paleta desde `qs.colors` (Material You). |
| **D-RADIUS** | `cornerRadius` y `gapsOut` **vivos** desde `hyprctl`. En esta máquina `decoration:rounding = 0` y `gaps_out = 0` (tema Tsukiyo, "Omarchy's square corners"). El token sigue a Hyprland; no se hardcodea. |
| **D-LINT** | Lint "cero números crudos" para `radius:`/`spacing`/padding/margins fuera de `Style.*`. |

## Alcance

**Incluye**: `Commons/Style.qml` + `Commons/qmldir`; absorción/retiro de `DesktopTheme.qml`; migración de radios/spacing/tipografía/estados/motion en `components/`, `modules/{anime,manga,novel}/`, `shell.qml`, `omarchy/pwnsxb.novelmangareader/Panel.qml`.

**Excluye**: backends/scrapers (`scripts/`), lógica funcional de servicios, datos del dueño, `~/.config/hypr/` y `/usr/share/omarchy/` (solo lectura).

## Constraints

- Sin atribución de IA en commits; Conventional Commits; **un commit por unidad**.
- Sin `qmldir` en el resto del proyecto (el nuevo `Commons/qmldir` es la excepción, como en Omarchy).
- Paleta Material You (`colors/Colors.json`) intacta.
- Verificación: lint + `hyprctl` + 3 módulos consistentes.

---

## Checklist de tareas

- [ ] **R1.0** — Feature doc + espejo Engram. *(este archivo)*
- [ ] **R1.1** — `Commons/Style.qml` (+`qmldir`): `cornerRadius`/`gapsOut` vivos; escala spacing/tipo idéntica a Omarchy; estados (normal/hover/selected/focus/pressed: fill/border alphas + anchos); motion (durations/easing). Retirar `services/DesktopTheme.qml` migrando sus consumidores (`ClickableRect`, `StyledText`, 16× `rad()`).
- [ ] **R1.2** — Migrar `components/**` → `Style.*` (radios/spacing/tipo/estados/motion).
- [ ] **R1.3** — Migrar `modules/anime/**` → `Style.*`.
- [ ] **R1.4** — Migrar `modules/manga/**` → `Style.*`.
- [ ] **R1.5** — Migrar `modules/novel/**` → `Style.*`.
- [ ] **R1.6** — `shell.qml` + `omarchy/pwnsxb.novelmangareader/Panel.qml` alineados al lenguaje de tokens; resto.
- [ ] **R1.7** — Lint `cero números crudos` (`tools/lint-style.js`) + test; verificación final (hyprctl + 3 módulos).

## Scope autorizado (superficies de edición)

| Tarea | Superficies |
|---|---|
| R1.0 | `odd/tasks/rediseno-ui-r1.md` |
| R1.1 | `Commons/Style.qml`, `Commons/qmldir`, `services/DesktopTheme.qml` (borrar), consumidores directos (`components/ClickableRect.qml`, `components/StyledText.qml`, call sites de `rad()`) |
| R1.2 | `components/**` |
| R1.3 | `modules/anime/**` |
| R1.4 | `modules/manga/**` |
| R1.5 | `modules/novel/**` |
| R1.6 | `shell.qml`, `omarchy/pwnsxb.novelmangareader/Panel.qml` |
| R1.7 | `tools/lint-style.js`, `tests/lint-style.test.js` |

---

## Diseño de tokens (`Commons/Style.qml`)

- **Live**: `cornerRadius` ← `hyprctl -j getoption decoration:rounding` → `.int`; `gapsOut` ← `general:gaps_out` (primer número / 2). `refresh()` re-lee.
- **Spacing** (idéntico a Omarchy): `xxs2 xs3 sm4 md6 lg8 xl10 xxl12 xxxl14 huge18`; `controlGap8 controlPadX10 controlPadY6`. Helper `space(n)`.
- **Tipografía** (escala Omarchy, base 12): `caption10 bodySmall11 body12 subtitle13 title14 heading16 display24 displayLarge28`; `icon 11/14/18`. Familias: `font.family="Noto Sans"`, `font.displayFamily="Noto Serif"` (tokens; el display se conserva, la escala es la de Omarchy).
- **Estados** (como Omarchy): fill alphas `normal .04 / hover .08 / selected .18 / pressed .22 / focus = hover`; border alphas `normal .4 / hover .25 / selected 1.0 / focus = hover`; border widths `normal 1 / hover 1 / selected 0 / focus 1`. Funciones `normalFillFor/hoverFillFor/...`, `controlFill/controlBorder/controlBorderWidth`, y colores convenience desde `qs.colors` (`foreground=Colors.text`, `accent=Colors.primary`, `urgent=Colors.error`).
- **Motion**: `fast=120` (color/estado), `base=140` (movimiento, `Easing.OutCubic`), `slow=240` (superficies/entrada), `loop=1000` (shimmer/spinner). Easing: `easeOut=OutCubic`, `easeInOut=InOutCubic`, `linear`.

## Criterios de aceptación

- Lint "cero números crudos" **verde** (0 violaciones de radius/spacing fuera de `Style.*`).
- `hyprctl -j getoption decoration:rounding` `.int` **==** `Style.cornerRadius`.
- Los 3 módulos usan los mismos paddings/tipos/radios/estados.
- Sin regresión funcional (backends intactos); sin errores QML al cargar.

## Checks

| Tarea | Checks |
|---|---|
| R1.1 | `qs -p` carga sin errores; `Style.cornerRadius` == hyprctl |
| R1.2–R1.6 | `node tools/lint-style.js` (progreso decreciente); carga sin errores |
| R1.7 | lint verde; `hyprctl` == token; 3 módulos |

## Ruta por tarea + evidencia del trigger

| Tarea | Ruta | Evidencia del trigger |
|---|---|---|
| R1.0 | inline | 1 archivo (doc) + mirror |
| R1.1 | inline | 1 archivo de diseño crítico (`Style.qml`) que el orquestador domina + consumidores mecánicos |
| R1.2 | delegado (writer) | 2+ archivos no triviales (`components/**`) |
| R1.3 | delegado (writer) | 2+ archivos (`modules/anime/**`) |
| R1.4 | delegado (writer) | 2+ archivos (`modules/manga/**`) |
| R1.5 | delegado (writer) | 2+ archivos (`modules/novel/**`) |
| R1.6 | inline | 1-2 archivos (`shell.qml` + Panel) |
| R1.7 | inline | 1 archivo nuevo (lint) + test |

## Forecast + estrategia de entrega

- **Forecast**: migración de 82 radios + ~124 durations + spacing en ~40 archivos → **muy por encima de ~400 líneas**.
- **Estrategia**: `work-unit commits` sobre la rama local (fork privado, **sin `origin`** → sin PRs). Un commit por tarea; cortes = unidades revisables.

---

## Progreso / evidencia

| Tarea | Commit | Estado |
|---|---|---|
| R1.0 | — | en curso |
| R1.1 | — | pendiente |
| R1.2 | — | pendiente |
| R1.3 | — | pendiente |
| R1.4 | — | pendiente |
| R1.5 | — | pendiente |
| R1.6 | — | pendiente |
| R1.7 | — | pendiente |

## Próximo paso

R1.1 — crear `Commons/Style.qml` + `Commons/qmldir` y retirar `DesktopTheme.qml`.
