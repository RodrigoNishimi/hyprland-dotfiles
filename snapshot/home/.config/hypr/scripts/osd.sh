#!/usr/bin/env bash
# OSD de volume / brilho via mako.
#
# Portado do kit Tokyo Night, com duas mudanças: usa wpctl (o mesmo do
# conf/keybinds.lua — misturar com pamixer daria leituras divergentes) e a
# barra não acende um bloco a mais quando o valor é 0.
#
#   osd.sh volume up|down|mute
#   osd.sh brightness up|down
set -euo pipefail

SINK="@DEFAULT_AUDIO_SINK@"

# Barra de 10 blocos. O printf com lista vazia imprimiria o formato uma vez,
# então cada metade só é chamada quando tem pelo menos um bloco.
bar() {
    local v=$1 filled empty
    filled=$(( v / 10 ))
    (( filled > 10 )) && filled=10
    empty=$(( 10 - filled ))
    (( filled > 0 )) && printf '━%.0s' $(seq "$filled")
    (( empty > 0 )) && printf '─%.0s' $(seq "$empty")
}

# x-canonical-private-synchronous faz o mako substituir a notificação anterior
# em vez de empilhar; int:value pinta a barra de progresso.
osd() {
    notify-send \
        -h string:x-canonical-private-synchronous:osd \
        -h int:value:"$1" \
        -c osd \
        "$2"
}

case "${1:-}" in
volume)
    case "${2:-}" in
    up)   wpctl set-volume -l 1.0 "$SINK" 5%+ ;;
    down) wpctl set-volume "$SINK" 5%- ;;
    mute) wpctl set-mute "$SINK" toggle ;;
    esac

    read -r _ raw muted <<< "$(wpctl get-volume "$SINK")"
    v=$(awk -v x="$raw" 'BEGIN { printf "%d", x * 100 + 0.5 }')

    if [[ ${muted:-} == "[MUTED]" ]]; then
        osd 0 "  mudo"
    else
        osd "$v" "  $(bar "$v")  $v"
    fi
    ;;
brightness)
    case "${2:-}" in
    up)   brightnessctl set 5%+ -q ;;
    down) brightnessctl set 5%- -q ;;
    esac

    v=$(( $(brightnessctl get) * 100 / $(brightnessctl max) ))
    osd "$v" "  $(bar "$v")  $v"
    ;;
*)
    echo "uso: osd.sh volume up|down|mute | osd.sh brightness up|down" >&2
    exit 1
    ;;
esac
