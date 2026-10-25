# qs-novelmangareader (fork en español)

Reproductor de anime, lector de manga y lector de novelas para
[Quickshell](https://quickshell.org), sacados de
[dhrruvsharma/shell](https://github.com/dhrruvsharma/shell) para poder usarlos sin el
resto de ese rice. Se abren como paneles laterales sobre el escritorio: manga y anime a
la izquierda, novelas a la derecha.

- **Anime:** explorar, buscar y biblioteca; los episodios se reproducen en `mpv`.
- **Manga:** explorar, buscar, favoritos, descargar y leer capítulos.
- **Novelas:** explorar, buscar, biblioteca, y leer en el panel o a pantalla completa.

Cada panel levanta un servidor Python local pequeño (`scripts/`) que consulta los sitios
de origen. Arrancan con el servicio del panel y solo escuchan en `127.0.0.1` (anime 5050,
manga 5150, novelas 5151).

> Este fork es **privado y local**: no se publica. El upstream del proyecto original es
> [dhrruvsharma/qs-novelmangareader](https://github.com/dhrruvsharma/qs-novelmangareader)
> (GPL-3.0); los errores del código original van a su repo, no aquí.

## Qué añade este fork

- **UI en español** (etiquetas, botones, estados, errores) con un **toggle EN/ES** que
  persiste, y **contenido en español** por defecto, que es una preferencia aparte.
- **Fuentes en español** para anime, manga y novelas (abajo).
- **Adopción de Omarchy**: la app toma tema, tipografía, radios y componentes de
  `qs.Commons` y `qs.Ui` en vez de mantener su propia copia.
- **Widget de barra** de Omarchy: un icono que abre un menú **Anime / Manga / Novelas**
  (`omarchy/pwnsxb.novelmangareader/`, con su propio README).

## Idioma: UI y contenido son independientes

| Qué | Variable | Precedencia / valor por defecto |
|---|---|---|
| **UI** (textos de los paneles) | `QS_LANG` | `QS_LANG` → `settings.json` del app → `LANG` → `en` |
| **Contenido** (subtítulos, capítulos) | `QS_CONTENT_LANG` | lista ordenada separada por comas; por defecto `es` |

El toggle **EN/ES** del panel escribe `<config>/qs-novelmangareader/settings.json` y
cambia la UI **en vivo**. `QS_LANG` manda sobre el archivo, y no se escribe nunca en el
código: el wrapper pasa el entorno tal cual. Así puedes leer contenido en español con la
UI en inglés, o al revés.

## Fuentes por panel

- **Anime:** hianime primero; si el stream no trae pista de subtítulos en español, cae a
  [JKAnime](https://jkanime.net) por título (subtítulos en español, hardsub).
- **Manga / manhwa:** cadena **MangaDex → InManga → zonatmo.net → zonatmo.org**, de modo
  que un título que falta en una fuente se busca en la siguiente. Las dos últimas son los
  dos backends independientes de ZonaTMO (una API JSON y el sitio HTML) que se respaldan
  entre sí; una fuente con el dominio caído se omite sin romper el panel.
  Se puede forzar una fuente con `QS_MANGA_SOURCE=mangadex|inmanga|zonatmo|zonatmo_org|weebcentral|auto`.
- **Novelas:** [SkyNovels](https://skynovels.net) en español; si el idioma de contenido no
  es español, FreeWebNovel (inglés).

Cuando ninguna fuente tiene capítulos en español, el lector lo dice claramente —nombrando
las fuentes que revisó— en vez de mostrar contenido como si fuera español. Si no hay
capítulos en español para un manga concreto, se muestra en inglés **con un aviso
prominente** en el detalle.

## Requisitos

- **Omarchy 4.0** con su shell de Quickshell. Es una dependencia dura: el repo enlaza
  `Commons/` y `Ui/` a `/usr/share/omarchy/shell/{Commons,Ui}`, así que no funciona sin
  Omarchy instalado. La app avisa en el log si la versión de Omarchy cambia de línea
  (ver *Omarchy* abajo).
- `qs` (Quickshell) — el que trae Omarchy, `python3` y `mpv`.
- Fuentes: Noto Sans y una Nerd Font (para los iconos).

## Instalar

```sh
git clone <este repo> ~/.config/qs-novelmangareader
~/.config/qs-novelmangareader/install.sh
```

Vive en su propia carpeta, `~/.config/qs-novelmangareader`, fuera de
`~/.config/quickshell`, así que corre junto a tu propia configuración de Quickshell (o sin
ninguna) sin tocarla.

`install.sh` hace todo:

- instala lo que los lectores necesitan con tu gestor de paquetes: Quickshell, Python, mpv,
  Noto Sans y curl (pacman en Arch; apt en Debian/Ubuntu y dnf en Fedora, que no empaquetan
  Quickshell, así que te dice dónde conseguirlo)
- descarga la fuente Symbols Nerd Font en `~/.local/share/fonts` si no tienes ninguna Nerd
  Font
- enlaza la carpeta a `~/.config/qs-novelmangareader` si la clonaste en otro sitio
- pone el comando `qs-novelmangareader` en tu `PATH`: en `~/.local/bin` si está en él; si
  no, (tras preguntar) en `/usr/local/bin`, para que funcione en cualquier shell y en los
  atajos del compositor desde el primer momento
- crea un venv con `flask`, `requests` y `curl_cffi` en
  `~/.local/share/qs-novelmangareader/venv` para los backends

Opciones: `--no-deps` (omite paquetes y fuentes), `--no-venv`, `--copy` (copia la carpeta
en vez de enlazarla), `--yes` (no pregunta).

Arranca al iniciar sesión con `qs-novelmangareader` (queda callado hasta que abres un panel).

## Comandos y atajos

Los tokens de comando son los mismos del original:

```sh
qs-novelmangareader           # arráncalo
qs-novelmangareader anime     # abre/cierra el reproductor de anime
qs-novelmangareader manga     # abre/cierra el lector de manga
qs-novelmangareader novel     # abre/cierra el lector de novelas
qs-novelmangareader stop      # ciérralo
qs-novelmangareader log       # su registro
```

Por debajo es `qs -p ~/.config/qs-novelmangareader …`, con los destinos IPC `animePlayer`,
`mangaReader` y `novelReader` (cada uno con `toggle`).

Hyprland:

```ini
exec-once = qs-novelmangareader
bind = SUPER ALT, A, exec, qs-novelmangareader anime
bind = SUPER ALT, M, exec, qs-novelmangareader manga
bind = SUPER ALT, N, exec, qs-novelmangareader novel
```

Sway:

```
exec qs-novelmangareader
bindsym $mod+Alt+a exec qs-novelmangareader anime
bindsym $mod+Alt+m exec qs-novelmangareader manga
bindsym $mod+Alt+n exec qs-novelmangareader novel
```

El botón de minimizar del header oculta el panel pero guarda tu lugar; el siguiente toggle
lo devuelve como lo dejaste.

## Widget de barra de Omarchy

El widget `pwnsxb.novelmangareader` vive en `omarchy/pwnsxb.novelmangareader/` y tiene su
propio README con la instalación (copiar o enlazar a `~/.config/omarchy/plugins/`) y cómo
añadirlo a la barra.

## Omarchy

La app se escribe contra **una línea de Omarchy: `4.0`**. Al arrancar ejecuta
`omarchy version` y, si el mayor/menor no coincide (o es un checkout `dev`), escribe **un**
aviso en el log; **no bloquea**: los paneles siguen abriendo.

```sh
qs-novelmangareader log | grep -i omarchy
```

El camino de actualización (actualizar, reiniciar shell y app, leer el log, correr las
suites y subir `supported` a propósito) está documentado en el README del widget, sección
*Updating Omarchy*.

## Colores

La paleta sale del tema de Omarchy (`qs.Commons.Color`, respaldado por
`~/.local/state/omarchy/current/theme/colors.toml`). No hay copia propia ni archivo de
paleta que mantener: cambiar el tema de Omarchy cambia la app. `app/Colors.qml` solo traduce
los nombres de rol que usan las vistas a los colores del sistema.
`extras/matugen/quickshell.json.hbs` es legado de antes de adoptar Omarchy y ya no se usa.

## Tus datos

- Bibliotecas y progreso de lectura: `~/.local/share/quickshell/{anime,manga}_library.json`,
  `~/.local/share/quickshell/new_novel_library.json`
- Descargas y cachés: `~/.local/share/quickshell-manga`, `~/.local/share/quickshell-novel`

Son las mismas rutas que usa el rice completo, así que moverse entre los dos conserva tu
biblioteca.

## Desarrollo y pruebas

```sh
node --test                  # i18n, lint de estilo, lint de i18n, CLI, guardia de Omarchy
node tools/lint-i18n.js      # literales en inglés sin I18n.t
node tools/lint-style.js     # números crudos de radio/espaciado/tipografía
python3 -m unittest discover -s tests -p "test_*.py"   # backends (fixtures, sin red)
```

Las pruebas de los backends usan fixtures grabadas y `HOME`/`XDG_DATA_HOME` temporales:
**nunca** apuntan a `~/.local/share/quickshell*` reales. Las pruebas en vivo contra los
sitios están detrás de variables de entorno opcionales (`INMANGA_LIVE_TESTS=1`).

## Licencia

GPL-3.0-or-later, la misma del rice del que viene. Ver `LICENSE`.
