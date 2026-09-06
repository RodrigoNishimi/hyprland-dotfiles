#!/usr/bin/env bash
# Rodapé do hyprlock: rede · bateria · uptime.
#
# Vive num script, e não dentro de um cmd[] no hyprlock.conf, porque o
# hyprlang interpola $1, ${...} e afins antes de o shell ver a linha.

# Consulte o estado já conhecido, sem disparar uma listagem/scan de redes. O
# timeout continua como proteção caso o NetworkManager não esteja respondendo.
network=$(timeout 1s nmcli -t -e no -f TYPE,STATE,CONNECTION device status 2>/dev/null)
ssid=$(sed -n 's/^wifi:connected://p' <<< "$network" | head -1)
if [[ -z $ssid ]]; then
    # Sem wifi ainda pode haver cabo: só então é de fato "offline".
    if awk -F: '$2 == "connected" && $1 != "wifi" && $1 != "loopback" { found=1 } END { exit !found }' <<< "$network"; then
        ssid="cabo"
    else
        ssid="offline"
    fi
fi

bat="--"
if [[ -r /sys/class/power_supply/BAT0/capacity ]]; then
    bat=$(< /sys/class/power_supply/BAT0/capacity)
fi

bat_icon=""
if [[ $bat =~ ^[0-9]+$ ]]; then
    if (( bat >= 90 )); then
        bat_icon=""
    elif (( bat >= 65 )); then
        bat_icon=""
    elif (( bat >= 40 )); then
        bat_icon=""
    elif (( bat >= 15 )); then
        bat_icon=""
    fi
fi

# Formato compacto e independente do idioma configurado no sistema.
up="?"
if read -r uptime_seconds _ < /proc/uptime; then
    uptime_seconds=${uptime_seconds%.*}
    up_hours=$((uptime_seconds / 3600))
    up_minutes=$(((uptime_seconds % 3600) / 60))
    up=$(printf '%dh %02dmin' "$up_hours" "$up_minutes")
fi

printf '  %s     %s  %s%%       %s\n' "$ssid" "$bat_icon" "$bat" "$up"
