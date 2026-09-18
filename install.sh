#!/usr/bin/env bash
# Install the current desktop snapshot; does not create backups.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
skip_packages=0
extra=0
dry=0
monitors=auto
gpu=auto
hardware=''
drivers_only=0
hardware_args=()
while (($#)); do
    case "$1" in
        --skip-packages) skip_packages=1 ;;
        --extra) extra=1 ;;
        --dry-run) dry=1 ;;
        --monitors) shift; monitors=${1:?use auto or original} ;;
        --gpu) shift; gpu=${1:?use auto or original} ;;
        --hardware) shift; hardware=${1:?use ryzen5600-rtx5070} ;;
        --drivers-only) drivers_only=1 ;;
        -h|--help)
            echo 'Usage: ./install.sh [--dry-run] [--skip-packages] [--extra] [--monitors auto|original] [--gpu auto|original]'
            echo '--extra includes optional packages from packages-extra.txt; --skip-packages skips both lists.'
            echo '--hardware ryzen5600-rtx5070 installs AMD microcode + NVIDIA open drivers and configures 1080p at 300 Hz.'
            echo '--drivers-only requires --hardware; installs only hardware packages, without applying dotfiles.'
            echo '--skip-packages also skips hardware packages. --dry-run previews all changes.'
            echo 'Overwrites managed files WITHOUT backups. Run as your desktop user.'
            exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done
[[ $monitors == auto || $monitors == original ]] || exit 2
[[ $gpu == auto || $gpu == original ]] || exit 2
[[ -z $hardware || $hardware == ryzen5600-rtx5070 ]] || { echo 'Unknown hardware profile.' >&2; exit 2; }
if (( drivers_only )) && { [[ -z $hardware ]] || (( skip_packages || extra )); }; then
    echo '--drivers-only requires --hardware and cannot be combined with --skip-packages or --extra.' >&2
    exit 2
fi
if [[ -n $hardware ]]; then
    [[ $monitors == auto && $gpu == auto ]] || { echo '--hardware cannot be combined with original monitor/GPU settings.' >&2; exit 2; }
    hardware_args=(--hardware "$hardware")
fi
(( EUID != 0 )) || { echo 'Run as your desktop user, not root.' >&2; exit 1; }

install_hardware() {
    local installed kernel
    local -a headers=() hardware_packages=(amd-ucode nvidia-open-dkms nvidia-utils libva-nvidia-driver)
    if (( skip_packages )); then
        echo 'Hardware packages skipped; applying the hardware configuration only.'
        return
    fi
    if (( dry )); then
        echo "Hardware packages: ${hardware_packages[*]} + headers for each installed linux/linux-lts/linux-zen/linux-hardened kernel."
        echo 'Would run sudo pacman -Syu --needed with those packages, then rebuild initramfs if mkinitcpio is available.'
        return
    fi
    command -v pacman >/dev/null || { echo 'Hardware installation requires Arch Linux.' >&2; return 1; }
    installed=$(pacman -Qq) || return
    while IFS= read -r kernel; do
        case "$kernel" in
            linux|linux-lts|linux-zen|linux-hardened) headers+=("$kernel-headers") ;;
        esac
    done <<< "$installed"
    ((${#headers[@]})) || { echo 'No supported kernel installed (linux, linux-lts, linux-zen, linux-hardened). Install the driver and matching headers manually for custom kernels.' >&2; return 1; }
    # Full upgrade avoids partial upgrades; DKMS supports all installed stock kernels.
    sudo pacman -Syu --needed "${hardware_packages[@]}" "${headers[@]}" || return
    if command -v mkinitcpio >/dev/null; then sudo mkinitcpio -P || return; fi
    echo 'Hardware packages installed. Reboot before starting Hyprland with the new driver.'
    echo 'For custom initramfs/boot setups, ensure AMD microcode is included (mkinitcpio microcode hook or bootloader entry).'
}

if (( drivers_only )); then
    install_hardware
    exit 0
fi
package_files=("$repo/packages.txt")
(( ! extra )) || package_files+=("$repo/packages-extra.txt")
if ((dry)); then
    echo "Dry run: dependencies from ${package_files[*]}; no packages, services or files will change."
    [[ -z $hardware ]] || install_hardware
    exec python3 "$repo/manage.py" install --dry-run --monitors "$monitors" --gpu "$gpu" "${hardware_args[@]}"
fi
# Catch incomplete snapshots and destination conflicts before changing the system.
python3 "$repo/manage.py" install --dry-run --monitors "$monitors" --gpu "$gpu" "${hardware_args[@]}"
[[ -z $hardware ]] || install_hardware
if (( ! skip_packages )); then
    command -v pacman >/dev/null || { echo 'Automatic package installation requires Arch Linux.' >&2; exit 1; }
    helper=''
    for candidate in paru yay; do
        if command -v "$candidate" >/dev/null; then helper=$candidate; break; fi
    done
    [[ -n $helper ]] || { echo 'Install paru or yay first (AUR packages such as eww are required), or use --skip-packages.' >&2; exit 1; }
    for package_file in "${package_files[@]}"; do
        [[ -r $package_file ]] || { echo "Missing package list: $package_file" >&2; exit 1; }
    done
    mapfile -t packages < <(awk '{ sub(/#.*/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if (NF && !seen[$0]++) print }' "${package_files[@]}")
    "$helper" -S --needed "${packages[@]}"
    sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon rtkit-daemon
fi
python3 "$repo/manage.py" install --monitors "$monitors" --gpu "$gpu" "${hardware_args[@]}"
mkdir -p "$HOME/Imagens/screenshots"
if (( ! skip_packages )) && [[ ! -e $HOME/.tmux/plugins/tpm ]]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
if command -v lua >/dev/null; then
    HOME="$HOME" XDG_CONFIG_HOME="$HOME/.config" \
        lua "$HOME/.config/eww/lua/build.lua"
fi
if command -v fc-cache >/dev/null; then fc-cache -f "$HOME/.local/share/fonts"; fi
echo 'Done. Use a Hyprland (uwsm) session. No session was reloaded automatically.'
