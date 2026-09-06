#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
packages=$(sed 's/#.*//; /^[[:space:]]*$/d' "$repo/packages.txt")
grep -Fxq pamixer <<<"$packages"
grep -Fxq rtkit <<<"$packages"

test_root=$(mktemp -d /tmp/hyprland-wrapper-test-XXXXXXXX)
trap 'rm -rf "$test_root"' EXIT
target_home="$test_root/home"
foreign_config="$test_root/foreign-config"
mkdir -p "$target_home" "$foreign_config/hypr/conf"
printf 'do not touch\n' >"$foreign_config/hypr/conf/rice.lua"

HOME="$target_home" XDG_CONFIG_HOME="$foreign_config" \
    "$repo/install.sh" --skip-packages --monitors auto --gpu auto >/dev/null

[[ $(cat "$foreign_config/hypr/conf/rice.lua") == 'do not touch' ]]
[[ -s "$target_home/.config/hypr/conf/rice.lua" ]]
grep -Fq 'mode = "preferred"' "$target_home/.config/hypr/conf/monitors.lua"
! grep -Eq 'LIBVA_DRIVER_NAME|__GLX_VENDOR_LIBRARY_NAME' "$target_home/.config/uwsm/env"
! rg -q '@@(HOME|ASSETS)@@|/home/ronis' \
    "$target_home/.config" "$target_home/.local/bin" "$target_home/.zshrc"

echo 'PASS: install.sh keeps generated files inside the target HOME'
