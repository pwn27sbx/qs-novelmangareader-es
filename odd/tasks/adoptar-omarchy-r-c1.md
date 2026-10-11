# qs-novelmangareader-es — Plan C: Adoptar Omarchy · R-C1 (adopción base)

| Campo | Valor |
|---|---|
| Feature ID | `adoptar-omarchy` |
| Rama | `i18n-es` (fork privado, sin `origin`) |
| Repo de trabajo | `~/Projects/forks/qs-novelmangareader-es` |
| Inicio | 2026-10-11 |
| Estado | **En curso** |
| Plan fuente | `/home/pwnsxb/Documents/Plans/2026-10-11-plan-c-adoptar-omarchy-qs-novelmangareader.md` (§4, §5.1, §9, §13) |
| Plan base | `2026-10-11-plan-rediseno-ui-qs-novelmangareader.md` (R1 ✅) |

> **Plan C supersede** el enfoque "espejo propio" de R1. La app **adopta Omarchy** por symlink. R1 sigue valiendo en **0 números crudos**: los componentes llaman `Style.*`, y ahora ese `Style` es el **de Omarchy**.

---

## Objetivo

Que la app siga el tema y el look del sistema: usar directamente `qs.Commons` (Color/Style/Util) y `qs.Ui` de Omarchy vía **symlink**, sin copias ni mantenimiento de espejo.

## Decisiones cerradas

| ID | Decisión |
|---|---|
| **D-SYMLINK** | `Commons/` y `Ui/` del repo → symlink a `/usr/share/omarchy/shell/{Commons,Ui}`. Se elimina el `Commons/qmldir` propio (choca con `module qs.Commons`). |
| **D-PALETTE** | **(A) Adapter**: singleton `Palette` en el módulo nuevo **`qs.app`**, con **los mismos nombres de rol** que hoy, respaldado por `qs.Commons.Color` + `Util.alpha` (+ un `mix` local para superficies sólidas). Los componentes cambian `import qs.colors` → `import qs.app` y el calificador `Colors.` → `Palette.`. |
| **D-MOTION** | `Style.motion.*` (173 usos, NO existe en Omarchy) → singleton **`Motion`** en `qs.app`; remapear `Style.motion.*` → `Motion.*`. `Style.font.displayFamily` (11) → `Style.font.family`. |
| **D-TEMA** | `Color` de Omarchy se auto-inicializa por `FileView` (`colors.toml`/`shell.toml`). Tema actual: **ristretto** (accent `#f38d70`). El `#cacccc` es una race de carga. |

## Alcance

**Incluye**: symlinks; módulo `qs.app` (Palette + Motion); migración de imports/calificadores; eliminación de `colors/` y del `Commons/` propio; smoke test; init del tema.

**Excluye**: migrar componentes ad-hoc a `qs.Ui` (eso es R2–R4); lógica/backends/datos; el widget de barra `pwnsxb.novelmangareader` (ya es plugin Omarchy).

## Constraints

- Conventional Commits, **sin atribución de IA**, commit por unidad.
- `lint-style` (0 números crudos) y `lint-i18n` siguen verdes.
- Dependencia dura: Omarchy instalado en `/usr/share/omarchy/shell`.
- No tocar backends/scrapers ni datos del dueño.

---

## Checklist de tareas

- [ ] **R-C1.0** — Feature doc + espejo Engram.
- [ ] **R-C1.1** — Módulo `qs.app`: `app/qmldir`, `app/Palette.qml` (adapter a `Color`), `app/Motion.qml`.
- [ ] **R-C1.2** — Symlinks `Commons`/`Ui` → Omarchy; eliminar `Commons/` propio y `colors/`.
- [ ] **R-C1.3** — Migrar imports (`qs.colors`→`qs.app`) + calificadores (`Colors.`→`Palette.`, `Style.motion.`→`Motion.`, `Style.font.displayFamily`→`Style.font.family`) en `components/**`, `modules/**`, `shell.qml`.
- [ ] **R-C1.4** — Smoke test: `import qs.Commons` + `import qs.Ui` + instanciar 1 componente; log de `Color.accent`/`Style.cornerRadius` al arranque.
- [ ] **R-C1.5** — Verificación: `Color.accent == colors.toml`; smoke OK; 0 tokens indefinidos; 0 errores QML; 3 módulos.

## Scope autorizado (superficies)

| Tarea | Superficies |
|---|---|
| R-C1.0 | `odd/tasks/adoptar-omarchy-r-c1.md` |
| R-C1.1 | `app/qmldir`, `app/Palette.qml`, `app/Motion.qml` |
| R-C1.2 | `Commons/` (borrar→symlink), `Ui` (symlink), `colors/` (borrar) |
| R-C1.3 | `components/**`, `modules/**`, `shell.qml` |
| R-C1.4 | `components/OmarchySmoke.qml`, `shell.qml` |
| R-C1.5 | — (verificación) |

## Criterios de aceptación

- `Color.accent` == accent del tema (`~/.local/state/omarchy/current/theme/colors.toml`) → hoy `#f38d70`.
- `import qs.Commons` + `import qs.Ui` cargan e instancian un componente (smoke).
- **0 tokens indefinidos** (`Style.motion`/`displayFamily` remapeados; todo `Style.*` resuelve).
- **0 errores QML** al cargar; los 3 módulos cargan.
- `lint-style` (0 crudos) y `lint-i18n` verdes; `node --test` verde.

## Checks

| Tarea | Checks |
|---|---|
| R-C1.2 | `ls -l Commons Ui` → symlinks; `qs -p` intenta cargar |
| R-C1.3 | `grep -rn "/*" ... ` — 0 `import qs.colors`, 0 `Colors.`, 0 `Style.motion`, 0 `displayFamily` |
| R-C1.4 | `qs -p` log `SMOKE ... accent=#f38d70` |
| R-C1.5 | los 3 módulos + lint + tests |

## Ruta por tarea

| Tarea | Ruta | Evidencia |
|---|---|---|
| R-C1.0 | inline | 1 doc + mirror |
| R-C1.1 | inline | 3 archivos nuevos de diseño (adapter) |
| R-C1.2 | inline | symlinks + borrados (bash) |
| R-C1.3 | inline (mecánico) | rename mecánico de tokens across files + verificación grep/lint |
| R-C1.4 | inline | 1 componente + wiring |
| R-C1.5 | inline (read-only) | verificación |

## Forecast + estrategia

- Rename mecánico en ~29 archivos (430 usos de paleta + 173 de motion) → > 400 líneas cambiadas.
- Estrategia: `work-unit commits` en la rama local (fork privado, sin PRs).

---

## Progreso / evidencia

| Tarea | Commit | Estado |
|---|---|---|
| R-C1.0 | — | en curso |
| R-C1.1 | — | pendiente |
| R-C1.2 | — | pendiente |
| R-C1.3 | — | pendiente |
| R-C1.4 | — | pendiente |
| R-C1.5 | — | pendiente |

## Próximo paso

R-C1.1 — crear el módulo `qs.app` (Palette + Motion).
