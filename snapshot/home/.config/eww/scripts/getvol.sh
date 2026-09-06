#!/usr/bin/env bash

EWW="/usr/bin/eww"
[ -x "$EWW" ] || EWW="eww"

update_vol() {
    local vol mute icon
    vol=$(pamixer --get-volume 2>/dev/null || echo 0)
    mute=$(pamixer --get-mute 2>/dev/null || echo false)

    if [ "$mute" = true ]; then
        icon="󰖁"
    elif [ "$vol" -ge 50 ]; then
        icon="󰕾"
    elif [ "$vol" -gt 0 ]; then
        icon="󰖀"
    else
        icon="󰕿"
    fi

    "$EWW" update volico="$icon" get_vol="$vol" 2>/dev/null
}

update_vol

pactl subscribe 2>/dev/null | stdbuf -oL grep --line-buffered "Event 'change' on sink" | while read -r _; do
    update_vol
done

