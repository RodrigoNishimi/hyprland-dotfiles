#!/usr/bin/env bash
# Título da janela em foco, uma linha por mudança. Linha vazia quando
# não há janela — a ilha se recolhe sozinha nesse caso.
emit() {
    hyprctl activewindow -j 2>/dev/null |
        jq -r 'if type == "object" and (.title // "") != ""
               then (.title | gsub("\\s+"; " "))
               else "" end' 2>/dev/null || echo ""
}

sig="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -td "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/"*/ 2>/dev/null | head -n1 | xargs -r basename)}"
sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${sig}/.socket2.sock"

emit

[ -S "$sock" ] || exit 0

stdbuf -oL socat -U - UNIX-CONNECT:"$sock" | while read -r line; do
    case $line in
        activewindow*|windowtitle*|closewindow*|openwindow*|focusedmon*|movewindow*|workspace*)
            emit
            ;;
    esac
done

