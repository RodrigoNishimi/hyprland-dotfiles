#!/usr/bin/env bash

sig="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -td "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/"*/ 2>/dev/null | head -n1 | xargs -r basename)}"
sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${sig}/.socket2.sock"

[ -S "$sock" ] || exit 0

socat -u UNIX-CONNECT:"$sock" - |
    stdbuf -o0 awk -F '>>|,' '/^activelayout>>/ { print toupper(substr($3, 1, 2)) }'

