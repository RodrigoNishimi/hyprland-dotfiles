#!/usr/bin/env bash

playerctl metadata -F -f '{{playerName}}|{{position}}|{{mpris:length}}' 2>/dev/null | while IFS='|' read -r player position length; do
    if [[ -n "$position" && "$position" =~ ^[0-9]+$ ]]; then
        pos_sec=$(( (position + 500000) / 1000000 ))
        mins=$((pos_sec / 60))
        secs=$((pos_sec % 60))
        pos_str=$(printf "%d:%02d" "$mins" "$secs")
    else
        pos_sec=0
        pos_str="0:00"
    fi
    jq -n -c \
      --argjson position "$pos_sec" \
      --arg positionStr "$pos_str" \
      '{position: $position, positionStr: $positionStr}'
done

