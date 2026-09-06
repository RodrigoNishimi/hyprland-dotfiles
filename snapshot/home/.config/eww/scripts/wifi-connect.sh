#!/usr/bin/env bash
# Eww 0.5 only supports exclusive keyboard focus. Enter passwords in a normal window.
set -euo pipefail
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/eww"
ssid=$(eww -c "$CFG" get wifissidrev)
[[ -n $ssid ]] || exit 1
"$CFG/scripts/panel.sh" wifictl close
exec ghostty -e nmtui-connect "$ssid"
