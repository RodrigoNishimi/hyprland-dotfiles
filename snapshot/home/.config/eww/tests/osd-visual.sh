#!/usr/bin/env bash
set -uo pipefail

CFG=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SHOT=$(mktemp --suffix=.png)
BASE=$(mktemp --suffix=.png)
RAW=$(mktemp)
BASE_RAW=$(mktemp)
trap 'eww -c "$CFG" close osd >/dev/null 2>&1 || true; rm -f "$SHOT" "$BASE" "$RAW" "$BASE_RAW"' EXIT

eww -c "$CFG" update osd_kind=brightness osd_value=80 osd_muted=false osd_label=80
eww -c "$CFG" open osd >/dev/null
sleep 0.3

layer=$(hyprctl -j layers | jq -c '[.[] .levels["3"][] | select(.y > 500)][0]')
namespace=$(jq -r '.namespace' <<< "$layer")
x=$(jq -r '.x' <<< "$layer")
y=$(jq -r '.y' <<< "$layer")
w=$(jq -r '.w' <<< "$layer")
h=$(jq -r '.h' <<< "$layer")

fail=0
if [[ $namespace != eww-osd ]]; then
    printf 'namespace do OSD: esperado eww-osd, obtido %s\n' "$namespace" >&2
    fail=1
fi

eww -c "$CFG" close osd >/dev/null
sleep 0.2
grim -g "$x,$y ${w}x${h}" "$BASE"
eww -c "$CFG" open osd >/dev/null
sleep 0.3
grim -g "$x,$y ${w}x${h}" "$SHOT"
ffmpeg -y -loglevel error -i "$SHOT" -f rawvideo -pix_fmt rgb24 "$RAW"
ffmpeg -y -loglevel error -i "$BASE" -f rawvideo -pix_fmt rgb24 "$BASE_RAW"
if ! python3 - "$RAW" "$BASE_RAW" "$w" "$h" <<'PY'
import sys

pixels = open(sys.argv[1], "rb").read()
base = open(sys.argv[2], "rb").read()
width, height = map(int, sys.argv[3:5])
# A barra amarela tem muitas amostras na mesma linha; o ícone não.
rows = []
for y in range(height):
    row = pixels[y * width * 3:(y + 1) * width * 3]
    count = sum(1 for x in range(width)
                if row[x * 3] > 180 and 120 < row[x * 3 + 1] < 210 and row[x * 3 + 2] < 150)
    if count > 30:
        rows.append(y)
if not rows:
    print("barra de brilho não encontrada", file=sys.stderr)
    raise SystemExit(1)
bar_center = (min(rows) + max(rows)) / 2
popup_center = (height - 1) / 2
delta = abs(bar_center - popup_center)
if delta > 2:
    print(f"barra fora do centro: centro={bar_center:.1f}, popup={popup_center:.1f}, delta={delta:.1f}px", file=sys.stderr)
    raise SystemExit(1)

# Fora do raio de 30px, os cantos da layer devem continuar transparentes.
for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
    offset = (y * width + x) * 3
    delta = sum(abs(pixels[offset + i] - base[offset + i]) for i in range(3))
    if delta > 3:
        print(f"canto retangular visível em ({x},{y}): delta={delta}", file=sys.stderr)
        raise SystemExit(1)
PY
then
    fail=1
fi

(( fail == 0 )) && printf 'osd visual: ok\n'
exit "$fail"
