#!/usr/bin/env bash
# Tempo ligado, compacto, para o cartão de horário.
read -r up _ < /proc/uptime
up=${up%.*}
d=$((up / 86400)); h=$((up % 86400 / 3600))
printf 'UP %02dD %02dH\n' "$d" "$h"
