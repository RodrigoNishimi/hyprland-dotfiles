#!/usr/bin/env bash
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/eww"
TMP=$(mktemp -d)
cleanup() {
    eww -c "$TMP/config" kill >/dev/null 2>&1 || true
    rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/config"
cp -a "$CFG/." "$TMP/config/"

cat >"$TMP/bin/playerctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$PLAYERCTL_CALLS"

case "$*" in
    '-l') printf 'paused\nbrowser\n' ;;
    '-p paused status') printf 'Paused\n' ;;
    '-p browser status') printf 'Playing\n' ;;
    '-p browser metadata title') printf 'Faixa de teste\n' ;;
    '-p browser metadata artist') printf 'Artista\n' ;;
    '-p browser metadata mpris:artUrl') printf '\n' ;;
    '-p browser metadata mpris:length') printf '125000000\n' ;;
    '-p browser position')
        position=$(cat "$FAKE_POSITION_FILE" 2>/dev/null || printf '65.400000')
        printf '%s\n' "$position"
        printf '66.400000\n' >"$FAKE_POSITION_FILE"
        ;;
    '-p browser position 10+'|'-p browser position 10-'|'-p browser previous'|'-p browser play-pause'|'-p browser next') ;;
    *)
if [[ $* == *'{{playerName}}|{{title}}'* ]]; then
    printf 'browser|Faixa de teste|Artista||Playing|125000000\n'
    sleep 10
elif [[ $* == *'{{playerName}}|{{position}}'* ]]; then
    printf 'browser|65400000|125000000\n'
    sleep 10
fi
    ;;
esac
EOF
chmod +x "$TMP/bin/playerctl"
export PLAYERCTL_CALLS="$TMP/playerctl.calls"
export FAKE_POSITION_FILE="$TMP/position"
export XDG_CACHE_HOME="$TMP/cache"
export PATH="$TMP/bin:$PATH"
: >"$PLAYERCTL_CALLS"

# A single snapshot must consistently select the playing player and keep all
# state (metadata, duration and position) tied to that same player.
if [[ -x "$TMP/config/scripts/media.sh" ]]; then
    snapshot=$("$TMP/config/scripts/media.sh" status)
    if ! jq -e '
        .available == true and .player == "browser" and
        .title == "Faixa de teste" and .artist == "Artista" and .hasArt == false and
        .status == "Playing" and .position == 65 and .length == 125 and
        .positionStr == "1:05" and .lengthStr == "2:05"
    ' <<<"$snapshot" >/dev/null; then
        echo 'FAIL: media snapshot is not coherent or correctly formatted' >&2
        failed=1
    fi
    next_snapshot=$("$TMP/config/scripts/media.sh" status)
    if ! jq -e '.position == 66 and .positionStr == "1:06"' <<<"$next_snapshot" >/dev/null; then
        echo 'FAIL: media position did not advance on the next poll' >&2
        failed=1
    fi
    : >"$PLAYERCTL_CALLS"
    "$TMP/config/scripts/media.sh" seek-forward
    mutations=$(grep -E ' (position 10[+-]|previous|play-pause|next)$' "$PLAYERCTL_CALLS" || true)
    if [[ $mutations != '-p browser position 10+' ]]; then
        echo 'FAIL: seek-forward did not target the displayed player' >&2
        failed=1
    fi
else
    echo 'FAIL: unified media state provider is missing' >&2
    failed=1
fi
failed=${failed:-0}

# Exercise the real widget under an isolated Eww daemon. Merely receiving a
# position update must never issue a seek command back to the player.
cat >>"$TMP/config/eww.yuck" <<'EOF'
(defwindow media_regression
  :monitor 0
  :geometry (geometry :width "360px" :height "240px" :anchor "top left")
  (music-player))
EOF

: >"$PLAYERCTL_CALLS"
eww -c "$TMP/config" daemon >/dev/null
for _ in {1..30}; do
    eww -c "$TMP/config" ping >/dev/null 2>&1 && break
    sleep 0.1
done
eww -c "$TMP/config" open media_regression >/dev/null
sleep 1

if awk '$0 ~ /(^| )position [^ ]+$/ { found=1 } END { exit !found }' "$PLAYERCTL_CALLS"; then
    echo 'FAIL: a programmatic slider update issued a seek command' >&2
    failed=1
fi

if (( failed != 0 )); then
    sed 's/^/playerctl: /' "$PLAYERCTL_CALLS" >&2
    exit 1
fi
echo 'PASS: media time advances and passive UI updates never seek'
