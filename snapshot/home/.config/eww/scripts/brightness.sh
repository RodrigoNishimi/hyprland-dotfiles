#!/usr/bin/env bash
# Sempre entrega um número, inclusive antes de o backlight estar disponível.
brightnessctl -c backlight -m 2>/dev/null | awk -F, '
    $4 ~ /^[0-9]+%$/ { sub(/%$/, "", $4); print ($4 < 1 ? 1 : $4); found=1; exit }
    END { if (!found) print 1 }
'
