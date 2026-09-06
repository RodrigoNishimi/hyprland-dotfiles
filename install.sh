#!/usr/bin/env bash
# Install the current desktop snapshot; does not create backups.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
skip_packages=0
dry=0
monitors=auto
gpu=auto
while (($#)); do
    case "$1" in
        --skip-packages) skip_packages=1 ;;
        --dry-run) dry=1 ;;
        --monitors) shift; monitors=${1:?use auto or original} ;;
        --gpu) shift; gpu=${1:?use auto or original} ;;
        -h|--help)
            echo 'Usage: ./install.sh [--dry-run] [--skip-packages] [--monitors auto|original] [--gpu auto|original]'
            echo 'Overwrites managed files WITHOUT backups. Run as your desktop user.'
            exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done
[[ $monitors == auto || $monitors == original ]] || exit 2
[[ $gpu == auto || $gpu == original ]] || exit 2
(( EUID != 0 )) || { echo 'Run as your desktop user, not root.' >&2; exit 1; }
if ((dry)); then
    echo 'Dry run: dependencies from packages.txt; no packages, services or files will change.'
    exec python3 "$repo/manage.py" install --dry-run --monitors "$monitors" --gpu "$gpu"
fi
if (( ! skip_packages )); then
    command -v pacman >/dev/null || { echo 'Automatic package installation requires Arch Linux.' >&2; exit 1; }
    helper=''
    for candidate in paru yay; do
        if command -v "$candidate" >/dev/null; then helper=$candidate; break; fi
    done
    [[ -n $helper ]] || { echo 'Install paru or yay first (AUR packages such as eww are required), or use --skip-packages.' >&2; exit 1; }
    mapfile -t packages < <(sed 's/#.*//; /^[[:space:]]*$/d' "$repo/packages.txt")
    "$helper" -S --needed "${packages[@]}"
    sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon
fi
python3 "$repo/manage.py" install --monitors "$monitors" --gpu "$gpu"
mkdir -p "$HOME/Imagens/screenshots"
if (( ! skip_packages )) && [[ ! -e $HOME/.tmux/plugins/tpm ]]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
if command -v lua >/dev/null; then lua "$HOME/.config/eww/lua/build.lua"; fi
if command -v fc-cache >/dev/null; then fc-cache -f "$HOME/.local/share/fonts"; fi
echo 'Done. Use a Hyprland (uwsm) session. No session was reloaded automatically.'
