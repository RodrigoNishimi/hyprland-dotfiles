#!/usr/bin/env bash
# Chips de workspace da barra: escuta o socket2 do Hyprland e reescreve
# linhas para `deflisten workspaces-output`, que a ilha renderiza com
# (literal). O desenho dos chips está em bar.scss (.tn-ws-chip).

WORKSPACES=6

ws() {
    local active_id ws_data
    active_id=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')
    ws_data=$(hyprctl workspaces -j 2>/dev/null)

    local occupied
    occupied=$(echo "$ws_data" | jq -r '[.[] | select((.windows // 0) > 0) | .id] | join(" ")' 2>/dev/null)

    local output="(box :class \"tn-ws\" :valign \"center\" :orientation \"h\" :spacing 5 :space-evenly \"false\""
    local i
    local -a ids
    # Preserve the six pinned chips and include any additional normal workspace.
    mapfile -t ids < <(jq -nr --argjson data "${ws_data:-[]}" --argjson count "$WORKSPACES" \
        --argjson active "${active_id:-1}" \
        '[range(1; $count + 1), ($data[] | .id | select(. > 0)), ($active | select(. > 0))] | unique[]')
    for i in "${ids[@]}"; do
        local class="tn-ws-chip tn-ws-free"
        if [[ "$active_id" == "$i" ]]; then
            class="tn-ws-chip tn-ws-active"
        elif [[ " $occupied " =~ [[:space:]]${i}[[:space:]] ]]; then
            class="tn-ws-chip tn-ws-occupied"
        fi
        output+=" (eventbox :onclick \"./scripts/switch-workspace.sh $i\" :cursor \"pointer\" :class \"tn-hit\" (box :valign \"center\" :class \"$class\" (label :yalign 0.5 :text \"$i\")))"
    done
    output+=")"

    printf '%s\n' "$output"
}

sig="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -td "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/"*/ 2>/dev/null | head -n1 | xargs -r basename)}"
SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${sig}/.socket2.sock"

ws

[ -S "$SOCKET" ] || exit 0

stdbuf -oL socat -U - UNIX-CONNECT:"$SOCKET" | while read -r line; do
    case $line in
        workspace*|createworkspace*|destroyworkspace*|openwindow*|closewindow*|movewindow*|focusedmon*|activewindow*|urgent*)
            ws
            ;;
    esac
done
