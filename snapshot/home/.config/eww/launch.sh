#!/usr/bin/env bash
# Eww owns the data listeners, including their lifetime on reload.
set -e
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/eww"
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/eww-${UID}-launch.lock"
flock -w 5 9
if ! eww -c "$CFG" ping >/dev/null 2>&1; then
    eww -c "$CFG" daemon 9>&-
    for ((attempt = 0; attempt < 50; attempt++)); do
        eww -c "$CFG" ping >/dev/null 2>&1 && break
        sleep 0.1
    done
    eww -c "$CFG" ping >/dev/null 2>&1 || { echo 'Eww não iniciou em 5 segundos.' >&2; exit 1; }
else
    eww -c "$CFG" reload
fi
"$CFG/scripts/bluetooth.sh" restore || true
eww -c "$CFG" open bar_widget
