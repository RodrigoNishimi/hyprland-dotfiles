#!/usr/bin/env bash
set -euo pipefail

MAKOCTL=${MAKOCTL:-makoctl}
action=${1:-status}

history_json() {
    "$MAKOCTL" history -j 2>/dev/null || printf '[]\n'
}

status() {
    local active history dnd
    active=$("$MAKOCTL" list -j 2>/dev/null || printf '[]\n')
    history=$(history_json)
    dnd=false
    if "$MAKOCTL" mode 2>/dev/null | grep -Fxq 'do-not-disturb'; then
        dnd=true
    fi

    jq -cn --argjson active "$active" --argjson history "$history" --argjson dnd "$dnd" '
        (($active + $history) | unique_by(.id) | sort_by(.id) | reverse) as $notifications |
        {
            count: ($notifications | length),
            dnd: $dnd,
            items: ($notifications[:8] | map({
                id,
                app: (if (.app_name // "") == "" then "Sistema" else .app_name end),
                summary: (.summary // "Notificação"),
                body: (.body // ""),
                urgency: (.urgency // "normal")
            }))
        }
    '
}

case "$action" in
    status)
        status
        ;;
    toggle-dnd)
        "$MAKOCTL" mode -t do-not-disturb
        ;;
    restore)
        "$MAKOCTL" restore
        ;;
    clear)
        "$MAKOCTL" dismiss --all --no-history
        count=$(history_json | jq 'length')
        for ((i = 0; i < count; i++)); do
            "$MAKOCTL" restore || break
            "$MAKOCTL" dismiss --no-history || break
        done
        ;;
    *)
        printf 'uso: %s {status|toggle-dnd|restore|clear}\n' "$0" >&2
        exit 2
        ;;
esac
