#!/usr/bin/env bash
# Hyprland's Lua dispatcher accepts a dispatch object, not legacy command syntax.
set -euo pipefail
workspace=${1:-}
[[ $workspace =~ ^[1-9][0-9]*$ ]] || exit 2
exec hyprctl dispatch "hl.dsp.focus({ workspace = $workspace })"
