#!/usr/bin/env bash
# Carga e estado da bateria para a ilha da direita.
# Sem bateria (desktop), present=false oculta a ilha.
bat=""
for b in /sys/class/power_supply/BAT*; do
    [ -r "$b/capacity" ] && { bat=$b; break; }
done

if [ -z "$bat" ]; then
    echo '{"cap":100,"charging":false,"present":false}'
    exit 0
fi

cap=$(cat "$bat/capacity" 2>/dev/null || echo 0)
status=$(cat "$bat/status" 2>/dev/null || echo Unknown)

case $status in
    Charging) charging=true ;;
    *)        charging=false ;;
esac

printf '{"cap":%d,"charging":%s,"present":true}\n' "$cap" "$charging"

