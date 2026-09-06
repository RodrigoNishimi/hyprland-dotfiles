#!/usr/bin/env bash
# Integration check: run inside the Hyprland session, with no panel initially open.
set -euo pipefail
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/eww"
panel() { "$CFG/scripts/panel.sh" "$@"; }
cleanup() {
    for name in usrctl wifictl calendar menuctl; do panel "$name" close; done
}
trap cleanup EXIT
before=$(hyprctl activewindow -j | jq -r '.address // ""')
for name in usrctl wifictl calendar menuctl usrctl wifictl; do
    panel "$name" open
    actual=$(eww -c "$CFG" active-windows | awk -F': ' '$1 != "bar_widget" { print $1 }')
    [[ $actual == "$name" ]] || { echo "Unexpected panels: $actual" >&2; exit 1; }
    after=$(hyprctl activewindow -j | jq -r '.address // ""')
    [[ $before == "$after" ]] || { echo "Keyboard focus changed opening $name" >&2; exit 1; }
    printf 'PASS: %s open, other panels closed, application focus retained\n' "$name"
done
cleanup
cleanup
[[ $(eww -c "$CFG" active-windows) == 'bar_widget: bar_widget' ]]
hyprctl layers -j | jq -e '[.[] .levels["3"][] | select(.namespace == "gtk-layer-shell")] | length == 0' >/dev/null
echo 'PASS: repeated close leaves no Eww overlay'
