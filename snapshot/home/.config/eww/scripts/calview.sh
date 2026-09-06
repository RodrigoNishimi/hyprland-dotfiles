#!/usr/bin/env bash
# Define o mês exibido no calendário: mês atual + offset (arg 1, padrão 0).
# Publica caloffset e calview no eww; o título vai em português porque o
# locale do sistema (en_US) não formata em pt-BR.
EWW=/usr/bin/eww
meses=(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)

off=${1:-0}
[[ $off =~ ^-?[0-9]+$ ]] || off=0

total=$(( (10#$(date +%Y) * 12) + (10#$(date +%m) - 1) + off ))
y=$(( total / 12 ))
m=$(( total % 12 ))

json=$(printf '{"month":%d,"year":%d,"title":"%s %d"}' "$m" "$y" "${meses[m]}" "$y")
"$EWW" update caloffset="$off" calview="$json"
