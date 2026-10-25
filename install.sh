#!/usr/bin/env bash
# Instalador de los lectores de Quickshell (anime, manga y novelas).
#
#   ./install.sh            instala los paquetes y las fuentes que necesitan, pone
#                           esta carpeta en ~/.config/qs-novelmangareader y el
#                           comando qs-novelmangareader en ~/.local/bin, y
#                           prepara el venv de Python para los backends
#   ./install.sh --no-deps  omite los paquetes del sistema y las fuentes
#   ./install.sh --no-venv  omite el venv de Python
#   ./install.sh --copy     copia la carpeta en vez de enlazarla
#   ./install.sh --yes      no pregunta antes de instalar
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/install-common.sh
source "$SRC_DIR/scripts/install-common.sh"

VENV="${XDG_DATA_HOME:-$HOME/.local/share}/qs-novelmangareader/venv"
PIP_PKGS=(flask requests curl_cffi)

PACMAN_PKGS=(quickshell python mpv noto-fonts curl)
APT_PKGS=(python3 python3-venv mpv fonts-noto-core curl)
DNF_PKGS=(python3 mpv google-noto-sans-fonts curl)
MANUAL=("quickshell: mira https://quickshell.org para paquetes y cómo compilarlo")

MODE=link
DEPS=1
VENV_SETUP=1
ASSUME_YES=0

while (($#)); do
    case $1 in
        --copy)    MODE=copy ;;
        --no-deps) DEPS=0 ;;
        --no-venv) VENV_SETUP=0 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "opción desconocida: $1" ;;
    esac
    shift
done

[[ $EUID -eq 0 ]] && die "ejecútalo como tu usuario normal, no como root"

if ((DEPS)); then
    install_system_packages
    install_nerd_symbols
fi

for cmd in quickshell python3 mpv; do
    command -v "$cmd" >/dev/null || warn "sigue faltando $cmd"
done

install_config qs-novelmangareader
install_command qs-novelmangareader

if ((VENV_SETUP)); then
    info "Preparando el venv de los backends en $VENV"
    [[ -x $VENV/bin/python3 ]] || python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --upgrade "${PIP_PKGS[@]}"
fi

cat <<MSG

Listo. Arráncalo con

    qs-novelmangareader

(ponlo en tu autostart) y enlaza teclas a

    qs-novelmangareader anime
    qs-novelmangareader manga
    qs-novelmangareader novel

Mira README.md para ejemplos de compositor y para los colores de matugen.
MSG
