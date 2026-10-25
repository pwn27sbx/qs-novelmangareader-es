# qs-novelmangareader-es — Plan C: Adoptar Omarchy · R-C1 (adopción base)

| Campo | Valor |
|---|---|
| Feature ID | `adoptar-omarchy` |
| Rama | `i18n-es` (fork privado, sin `origin`) |
| Repo de trabajo | `~/Projects/forks/qs-novelmangareader-es` |
| Inicio | 2026-10-11 |
| Estado | **CULMINADO (2026-10-25)** — R-C1 `69d0224`..`eaa4a30`, R-C2 `a08ed7f` + `3fff8f7` |
| Plan fuente | `/home/pwnsxb/Documents/ObsidianVault/QS NovelMangaReader/2026-10-11-plan-c-adoptar-omarchy-qs-novelmangareader.md` (§4, §5.1, §9, §13) |
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
- [x] **R-C1.3** — Migrar imports (`qs.colors`→`qs.app`) + calificadores (`Colors.`→`Palette.`, `Style.motion.`→`Motion.`, `Style.font.displayFamily`→`Style.font.family`) en `components/**`, `modules/**`, `shell.qml`.
- [x] **R-C1.4** — Smoke test: `import qs.Commons` + `import qs.Ui` + instanciar 1 componente; log de `Color.accent`/`Style.cornerRadius` al arranque.
- [x] **R-C1.5** — Verificación: `Color.accent == colors.toml`; smoke OK; 0 tokens indefinidos; 0 errores QML; 3 módulos.

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
| R-C1.0 | `69d0224` | ✅ completo |
| R-C1.1 | `3a03421` | ✅ completo |
| R-C1.2 / R-C1.3 | `8d23283` | ✅ completo |
| R-C1.4 | `eaa4a30` | ✅ completo |
| R-C1.5 | — | ✅ completo (evidencia abajo) |

### Evidencia de verificación (cierre R-C1)

- **Symlinks**: `Commons -> /usr/share/omarchy/shell/Commons`, `Ui -> /usr/share/omarchy/shell/Ui`.
- **Smoke**: log `SMOKE qs.Commons+qs.Ui ok | accent=#f38d70 | cornerRadius=0 | button=ok` → `import qs.Commons` + `import qs.Ui` cargan e instancian un `Button`.
- **`Color.accent` == `colors.toml`**: `#f38d70` == accent del tema **ristretto** (`~/.local/state/omarchy/current/theme/colors.toml`). El `#cacccc` era la race de carga (se resuelve al instanciar `Color`).
- **0 tokens indefinidos**: `grep` → 0 `Style.motion`, 0 `Style.font.displayFamily`, 0 `import qs.colors`, 0 `Colors.`; todo `Colors.`/`Motion.` importa `qs.app`; todo `Style.` importa `qs.Commons`.
- **0 errores QML**: carga real + toggle IPC de **los 3 módulos** → **0 TypeError / 0 "Unable to assign"**. (Únicos WARN: bibliotecas JSON del dueño inexistentes → comportamiento normal.)
- **Gates**: `lint-style` OK (36 files, 0 crudos) · `lint-i18n` OK · `node --test` **29/29**.

### Hallazgo de colisión

El singleton se llamó primero `Palette`, que **colisiona con el tipo `Palette` de QtQuick** (los roles salían `undefined` y `withAlpha` "no era función"). Se renombró a **`Colors`** en `qs.app`; así los componentes cambian **solo el import** (`qs.colors` → `qs.app`), tal como pedía la decisión.

## Próximo paso al cierre de R-C1 (histórico)

R-C1 quedó cerrada. Siguiente en ese momento: **R-C2 — guardia de versión `omarchy version`** (+ doc de update), y luego **R2 — superficie/header/navegación con `qs.Ui`** (`PopupCard`, `Panel`, `ButtonGroup`). R-C2 se completó el 2026-10-25 (bloque de abajo); el próximo paso **vigente** está al final de este archivo.

---

# R-C2 — Guardia de versión de Omarchy

> Spec: plan C §6 (`2026-10-11-plan-c-adoptar-omarchy-qs-novelmangareader.md`): la app declara
> `SUPPORTED_OMARCHY`, lee `omarchy version` al arrancar y **avisa** (no bloquea) cuando el
> mayor/menor no coincide. Añadido: documentar el camino de actualización.

| Campo | Valor |
|---|---|
| Inicio / cierre | 2026-10-25 |
| Estado | **Completo** |

## Checklist

- [x] **R-C2.1** — `services/omarchy_version.js`: `parseVersion()` (`4.0.6-1`→`4.0`, `dev (hash)`→`dev`, resto ``), `isSupported()`, `warningMessage()`.
- [x] **R-C2.2** — `services/OmarchyVersion.qml`: singleton con `supported = "4.0"`, `Process(["omarchy","version"])` y **un** `console.warn` cuando no coincide.
- [x] **R-C2.3** — `shell.qml`: `Component.onCompleted: OmarchyVersion.check()` (arranque del app).
- [x] **R-C2.4** — Camino de actualización documentado en `omarchy/pwnsxb.novelmangareader/README.md` (§ *Supported Omarchy*, § *Updating Omarchy*).
- [x] **R-C2.5** — Tests `tests/omarchy_version.test.js` (6) + verificación en vivo.

## Decisiones

- **Solo mayor.menor**: un parche (4.0.7) no debe avisar; un cambio de línea (4.5) sí.
- **`dev` siempre avisa**: un checkout (`OMARCHY_PATH` a un repo) no tiene línea de release que comparar; avisar es más honesto que adivinar.
- **No bloquea**: el aviso va al log (`qs-novelmangareader log`), las tres pantallas siguen abriendo. El modo "safe" del plan sigue siendo opcional y **no** se implementó (requiere decisión de producto).
- **JS puro testeable**: el parseo vive en `services/omarchy_version.js` con funciones top-level y `module.exports` guardado (mismo patrón que `anime_links.js`), porque QML importa el archivo como `Core.*` y `node --test` como módulo.

## Evidencia

- `node --test tests/omarchy_version.test.js` → **6/6**.
- En vivo (máquina, Omarchy 4.0.6): `GUARD supported=4.0 running=4.0 ok=true` → **sin** warning.
- En vivo (warning): `omarchy` falso en `PATH` que imprime `4.5.0-1` →
  `WARN qs-novelmangareader: Omarchy 4.5 is not the supported 4.0: qs.Commons/qs.Ui may have changed…`.
- App real: sin warning, `SMOKE … accent=#7daea3`, header/tabs/filtros visibles.

## Próximo paso

R-C2 cerrada. Siguiente: **WU-9** (instalador/CLI/README) y luego **R2**.

