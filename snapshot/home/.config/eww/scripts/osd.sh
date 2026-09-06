#!/usr/bin/env bash
set -euo pipefail

CFG=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EWW_BIN=${EWW_BIN:-eww}
SINK='@DEFAULT_AUDIO_SINK@'

show_osd() {
    local kind=$1 value=$2 muted=$3 label=$4
    "$EWW_BIN" -c "$CFG" update \
        "osd_kind=$kind" "osd_value=$value" "osd_muted=$muted" "osd_label=$label"
    "$EWW_BIN" -c "$CFG" open osd || true

    [[ ${EWW_OSD_NO_TIMER:-0} == 1 ]] && return
    local runtime=${XDG_RUNTIME_DIR:-/tmp}
    local stamp_file="$runtime/eww-osd-$UID.stamp"
    local stamp
    stamp=$(date +%s%N)
    printf '%s\n' "$stamp" > "$stamp_file"
    (
        sleep 1.6
        [[ $(cat "$stamp_file" 2>/dev/null) == "$stamp" ]] && \
            "$EWW_BIN" -c "$CFG" close osd >/dev/null 2>&1 || true
    ) &
}

case "${1:-}" in
volume)
    case "${2:-}" in
    up)   wpctl set-volume -l 1.0 "$SINK" 5%+ ;;
    down) wpctl set-volume "$SINK" 5%- ;;
    mute) wpctl set-mute "$SINK" toggle ;;
    *) printf 'uso: %s volume up|down|mute\n' "$0" >&2; exit 1 ;;
    esac

    read -r _ raw muted_state <<< "$(wpctl get-volume "$SINK")"
    value=$(awk -v x="$raw" 'BEGIN { printf "%d", x * 100 + 0.5 }')
    if [[ ${muted_state:-} == '[MUTED]' ]]; then
        show_osd volume "$value" true mudo
    else
        show_osd volume "$value" false "$value"
    fi
    ;;
brightness)
    case "${2:-}" in
    up)   brightnessctl set 5%+ -q ;;
    down) brightnessctl set 5%- -q ;;
    *) printf 'uso: %s brightness up|down\n' "$0" >&2; exit 1 ;;
    esac
    current=$(brightnessctl get)
    maximum=$(brightnessctl max)
    value=$(( current * 100 / maximum ))
    show_osd brightness "$value" false "$value"
    ;;
*)
    printf 'uso: %s volume up|down|mute | brightness up|down\n' "$0" >&2
    exit 1
    ;;
esac
