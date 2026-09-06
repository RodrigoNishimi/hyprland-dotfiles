#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/runtime"

cat > "$TMP/bin/wpctl" <<'EOF'
#!/usr/bin/env bash
printf 'wpctl %s\n' "$*" >> "$OSD_TEST_LOG"
if [[ $1 == get-volume ]]; then
    printf '%s\n' "${OSD_TEST_VOLUME:-Volume: 0.62}"
fi
EOF

cat > "$TMP/bin/brightnessctl" <<'EOF'
#!/usr/bin/env bash
printf 'brightnessctl %s\n' "$*" >> "$OSD_TEST_LOG"
case "${1:-}" in
get) printf '80\n' ;;
max) printf '100\n' ;;
esac
EOF

cat > "$TMP/bin/eww" <<'EOF'
#!/usr/bin/env bash
printf 'eww %s\n' "$*" >> "$OSD_TEST_LOG"
EOF

chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH"
export OSD_TEST_LOG="$TMP/calls"
export XDG_RUNTIME_DIR="$TMP/runtime"
export EWW_OSD_NO_TIMER=1

assert_log() {
    local expected=$1
    if ! grep -Fqx -- "$expected" "$OSD_TEST_LOG"; then
        printf 'linha ausente: %s\n\nlog:\n' "$expected" >&2
        cat "$OSD_TEST_LOG" >&2
        exit 1
    fi
}

# Regressão protegida: aumentar volume deve alterar o sink e mostrar 62%.
: > "$OSD_TEST_LOG"
"$ROOT/scripts/osd.sh" volume up
assert_log 'wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+'
assert_log 'eww -c @@HOME@@/.config/eww update osd_kind=volume osd_value=62 osd_muted=false osd_label=62'
assert_log 'eww -c @@HOME@@/.config/eww open osd'

# Regressão protegida: mute deve renderizar o cartão compacto, sem progresso.
: > "$OSD_TEST_LOG"
OSD_TEST_VOLUME='Volume: 0.62 [MUTED]' "$ROOT/scripts/osd.sh" volume mute
assert_log 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'
assert_log 'eww -c @@HOME@@/.config/eww update osd_kind=volume osd_value=62 osd_muted=true osd_label=mudo'
assert_log 'eww -c @@HOME@@/.config/eww open osd'

# Regressão protegida: brilho deve usar o valor percentual calculado.
: > "$OSD_TEST_LOG"
"$ROOT/scripts/osd.sh" brightness down
assert_log 'brightnessctl set 5%- -q'
assert_log 'eww -c @@HOME@@/.config/eww update osd_kind=brightness osd_value=80 osd_muted=false osd_label=80'
assert_log 'eww -c @@HOME@@/.config/eww open osd'

printf 'osd: ok\n'
