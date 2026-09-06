#!/usr/bin/env bash
# One transition across all panels. Never hide an input surface before closing it.
set -euo pipefail
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/eww"
eww() { command eww -c "$CFG" "$@"; }
panel=${1:?panel required}
action=${2:-toggle}
case "$panel" in
    usrctl) flag=ctlrev ;;
    wifictl) flag=wifictlrev ;;
    calendar) flag=calrev ;;
    menuctl) flag=menurev ;;
    *) exit 2 ;;
esac
case "$action" in toggle|open|close) ;; *) exit 2 ;; esac
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/eww-${UID}-panels.lock"
flock -w 1 9
windows=$(eww active-windows)
has_window() {
    awk -F': ' -v panel="$1" '$1 == panel { found=1 } END { exit !found }' <<< "$windows"
}
is_open=false
if has_window "$panel"; then
    is_open=true
fi
if [[ $action == toggle ]]; then
    if $is_open; then action=close; else action=open; fi
fi
if [[ $action == close ]]; then
    # Close first: a killed callback must not leave an invisible overlay behind.
    if $is_open; then eww close "$panel"; fi
    eww update "$flag=false"
    if [[ $panel == wifictl ]]; then eww update wificonfigrev=false; fi
else
    # Switching panels is synchronous; no delayed background toggle can reopen one.
    for other in usrctl wifictl calendar menuctl; do
        if [[ $other != "$panel" ]] && has_window "$other"; then
            eww close "$other"
        fi
    done
    # Set visible state before opening the surface, for the same interruption safety.
    eww update ctlrev=false wifictlrev=false calrev=false menurev=false \
        wificonfigrev=false "$flag=true"
    if [[ $panel == calendar ]] && ! $is_open; then
        "$(dirname "$0")/calview.sh" 0
    fi
    if ! $is_open; then eww open "$panel"; fi
fi
