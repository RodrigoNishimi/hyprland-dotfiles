#!/usr/bin/env bash
set -euo pipefail

config_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/eww/media"
player_file="$cache_dir/player"
art_url_file="$cache_dir/art-url"
cover_file="$cache_dir/cover"
fallback_cover="$config_dir/scripts/cover.png"
mkdir -p "$cache_dir"

player_status() {
    playerctl -p "$1" status 2>/dev/null || true
}

remember_player() {
    local temporary="$player_file.tmp.$$"
    printf '%s\n' "$1" >"$temporary"
    mv -f "$temporary" "$player_file"
}

choose_player() {
    local current="" player status fallback=""
    local -a players=()
    mapfile -t players < <(playerctl -l 2>/dev/null || true)
    ((${#players[@]})) || return 1

    [[ -r $player_file ]] && IFS= read -r current <"$player_file"
    if [[ -n $current ]]; then
        for player in "${players[@]}"; do
            if [[ $player == "$current" && $(player_status "$player") == Playing ]]; then
                printf '%s\n' "$player"
                return 0
            fi
        done
    fi

    for player in "${players[@]}"; do
        status=$(player_status "$player")
        [[ -n $fallback ]] || fallback=$player
        if [[ $status == Playing ]]; then
            printf '%s\n' "$player"
            return 0
        fi
    done

    if [[ -n $current ]]; then
        for player in "${players[@]}"; do
            if [[ $player == "$current" ]]; then
                printf '%s\n' "$player"
                return 0
            fi
        done
    fi
    printf '%s\n' "$fallback"
}

format_time() {
    local total=$1
    if ((total >= 3600)); then
        printf '%d:%02d:%02d' "$((total / 3600))" "$(((total % 3600) / 60))" "$((total % 60))"
    else
        printf '%d:%02d' "$((total / 60))" "$((total % 60))"
    fi
}

empty_state() {
    jq -nc '{available:false,hasArt:false,player:"",title:"",artist:"",thumbnail:"",status:"Stopped",length:0,position:0,progress:0,lengthStr:"0:00",positionStr:"0:00"}'
}

update_cover() {
    local art_url=$1 previous_url=""
    [[ -r $art_url_file ]] && IFS= read -r previous_url <"$art_url_file"

    if [[ -n $art_url && ($art_url != "$previous_url" || ! -s $cover_file) ]]; then
        local temporary="$cover_file.tmp.$$"
        if curl --fail --location --silent --show-error --max-time 3 --output "$temporary" "$art_url" 2>/dev/null; then
            mv -f "$temporary" "$cover_file"
            printf '%s\n' "$art_url" >"$art_url_file"
        else
            rm -f "$temporary"
        fi
    fi

    if [[ -s $cover_file && -n $art_url ]]; then
        printf '%s\n' "$cover_file"
    else
        printf '%s\n' "$fallback_cover"
    fi
}

status_snapshot() {
    local player status title artist art_url length_us position_raw
    local length=0 position=0 progress=0 thumbnail
    player=$(choose_player) || {
        rm -f "$player_file"
        empty_state
        return
    }
    remember_player "$player"

    status=$(player_status "$player")
    title=$(playerctl -p "$player" metadata title 2>/dev/null || true)
    artist=$(playerctl -p "$player" metadata artist 2>/dev/null || true)
    art_url=$(playerctl -p "$player" metadata mpris:artUrl 2>/dev/null || true)
    length_us=$(playerctl -p "$player" metadata mpris:length 2>/dev/null || true)
    position_raw=$(playerctl -p "$player" position 2>/dev/null || true)

    [[ $length_us =~ ^[0-9]+$ ]] && length=$((length_us / 1000000))
    [[ $position_raw =~ ^[0-9]+([.][0-9]+)?$ ]] && position=${position_raw%%.*}
    ((position < 0)) && position=0
    if ((length > 0)); then
        ((position > length)) && position=$length
        progress=$((position * 100 / length))
    fi

    [[ -n $title ]] || title="Sem título"
    [[ -n $artist ]] || artist=$player
    [[ -n $status ]] || status="Paused"
    thumbnail=$(update_cover "$art_url")

    jq -nc \
        --arg player "$player" \
        --arg title "$title" \
        --arg artist "$artist" \
        --arg thumbnail "$thumbnail" \
        --arg status "$status" \
        --argjson hasArt "$([[ -n $art_url ]] && printf true || printf false)" \
        --argjson length "$length" \
        --argjson position "$position" \
        --argjson progress "$progress" \
        --arg lengthStr "$(format_time "$length")" \
        --arg positionStr "$(format_time "$position")" \
        '{available:true,hasArt:$hasArt,player:$player,title:$title,artist:$artist,thumbnail:$thumbnail,status:$status,length:$length,position:$position,progress:$progress,lengthStr:$lengthStr,positionStr:$positionStr}'
}

control() {
    local action=$1 player="" candidate
    local -a players=()
    mapfile -t players < <(playerctl -l 2>/dev/null || true)
    [[ -r $player_file ]] && IFS= read -r candidate <"$player_file"
    for player in "${players[@]}"; do
        [[ $player == "$candidate" ]] && break
    done
    if [[ -z $candidate || $player != "$candidate" ]]; then
        player=$(choose_player) || return 0
    else
        player=$candidate
    fi
    remember_player "$player"
    case "$action" in
        previous|play-pause|next) playerctl -p "$player" "$action" ;;
        seek-backward) playerctl -p "$player" position 10- ;;
        seek-forward) playerctl -p "$player" position 10+ ;;
        *) printf 'Unknown media action: %s\n' "$action" >&2; return 2 ;;
    esac
}

case "${1:-status}" in
    status) status_snapshot ;;
    previous|play-pause|next|seek-backward|seek-forward) control "$1" ;;
    *) printf 'Usage: %s [status|previous|play-pause|next|seek-backward|seek-forward]\n' "$0" >&2; exit 2 ;;
esac
