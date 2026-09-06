#!/usr/bin/env bash
# Read the radio itself: enabled Wi-Fi can be disconnected from any network.
set -euo pipefail
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/eww"

radio_state() {
    LC_ALL=C nmcli --wait 3 radio wifi
}

publish_state() {
    local state
    state=$(radio_state) || return
    case "$state" in
        enabled) printf '{"enabled":true}\n' ;;
        disabled) printf '{"enabled":false}\n' ;;
        *) return 1 ;;
    esac
}

case "${1:-status}" in
    status) publish_state ;;
    toggle)
        exec 9>"${XDG_RUNTIME_DIR:-/tmp}/eww-${UID}-wifi-radio.lock"
        flock -n 9 || exit 0
        state=$(radio_state)
        case "$state" in
            enabled) nmcli --wait 5 radio wifi off ;;
            disabled) nmcli --wait 5 radio wifi on ;;
            *) exit 1 ;;
        esac
        eww -c "$CFG" update wifi_radio="$(publish_state)"
        eww -c "$CFG" update wifistatus="$("$CFG/scripts/current-wifi.sh")"
        ;;
    *) exit 2 ;;
esac
