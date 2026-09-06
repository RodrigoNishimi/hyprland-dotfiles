#!/bin/bash

# Bluetooth control for the user panel.
#   (no args)                  -> print controller state as JSON (defpoll)
#   devices                    -> print known devices as a JSON array (defpoll)
#   toggle                     -> power the controller on/off
#   restore                    -> restore the last state selected with toggle
#   scan                       -> short discovery pass
#   connect|disconnect|remove MAC

EWW="/usr/bin/eww"

# bluetoothctl connect/pair can block forever on a device that advertises but
# never answers (an LE-only record, or a headset that left pairing mode). Under
# the panel these run detached, so an unbounded call would sit there holding the
# adapter and every later pairing attempt fails with AuthenticationFailed.
BT_TIMEOUT=20
BT_LOCK="${XDG_RUNTIME_DIR:-/tmp}/eww-bluetooth.lock"
BT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/eww"
BT_STATE="$BT_STATE_DIR/bluetooth-power"

btctl(){
    timeout "$BT_TIMEOUT" bluetoothctl "$@"
}

# one adapter action at a time, so repeated clicks cannot pile up
lock_or_exit(){
    # note: no redirection on the exec itself - "exec 9>f 2>/dev/null" would
    # silence stderr for the whole script, swallowing every error below
    : >>"$BT_LOCK" 2>/dev/null || exit 1
    exec 9>"$BT_LOCK"
    if ! flock -n 9; then
        echo "bluetooth: another action is still running" >&2
        exit 0
    fi
}

sanitize(){
    printf '%s' "$1" | tr -d '"\\' | tr -d '\n'
}

controller_powered(){
    bluetoothctl show 2>/dev/null | awk '/[[:space:]]Powered:/ {print $2; exit}'
}

remember_power(){
    local state=$1 tmp
    mkdir -p "$BT_STATE_DIR"
    tmp="$BT_STATE.tmp.$$"
    printf '%s\n' "$state" > "$tmp"
    mv -f "$tmp" "$BT_STATE"
}

restore_power(){
    local desired current
    lock_or_exit

    # BlueZ may still be starting when Hyprland launches the bar.
    for _ in $(seq 1 12); do
        current=$(controller_powered)
        case "$current" in yes|no) break ;; esac
        sleep 0.25
    done
    case "$current" in yes|no) ;; *) return 1 ;; esac

    # On the first run, adopt the current controller state.
    if [ ! -r "$BT_STATE" ]; then
        [ "$current" = yes ] && remember_power on || remember_power off
        return
    fi

    desired=$(head -n 1 "$BT_STATE")
    case "$desired" in on|off) ;; *) return 1 ;; esac

    if [ "$desired" = on ]; then
        rfkill unblock bluetooth >/dev/null 2>&1 || true
        [ "$current" = yes ] || btctl power on >/dev/null 2>&1
    else
        [ "$current" != yes ] || btctl power off >/dev/null 2>&1
    fi
}

status_json(){
    local powered name count cmac cname cinfo

    powered=$(controller_powered)
    if [ "$powered" != "yes" ]; then
        echo '{"powered": false, "icon": "󰂲", "label": "Off", "class": "bt-off", "count": 0}'
        return
    fi

    count=$(bluetoothctl devices 2>/dev/null | awk '$1=="Device" {mac=$2; gsub(/:/,"-",mac); name=substr($0, index($0,$3)); if (name != mac) c++} END {print c+0}')

    # A failed attempt can leave a bare LE link open (battery service only, no
    # audio). BlueZ still calls that "connected", so only report a device that
    # carries a real profile: a BR/EDR record, or one that is actually paired.
    name=""
    while read -r _ cmac cname; do
        [ -z "$cmac" ] && continue
        cinfo=$(bluetoothctl info "$cmac" 2>/dev/null)
        if echo "$cinfo" | grep -q "Class:" || echo "$cinfo" | grep -q "Paired: yes"; then
            name="$cname"
            break
        fi
    done < <(bluetoothctl devices Connected 2>/dev/null)

    if [ -n "$name" ]; then
        echo "{\"powered\": true, \"icon\": \"󰂱\", \"label\": \"$(sanitize "$name")\", \"class\": \"bt-conn\", \"count\": $count}"
    else
        echo "{\"powered\": true, \"icon\": \"󰂯\", \"label\": \"On\", \"class\": \"bt-on\", \"count\": $count}"
    fi
}

# BlueZ reports one entry per transport, so a headset shows up twice under the
# same name: a BR/EDR record (has a Class, this is the one that carries audio)
# and a bare LE advert. Keep the richest record per name so a click cannot land
# on the entry that pairs but plays nothing.
type_icon(){
    case $1 in
        audio-headset|audio-headphones) echo "󰋋";;
        audio-card)                     echo "󰓃";;
        input-mouse)                    echo "󰦋";;
        input-keyboard)                 echo "󰌌";;
        input-gaming)                   echo "󰊴";;
        phone)                          echo "󰄜";;
        computer)                       echo "󰟀";;
        *)                              echo "󰂯";;
    esac
}

devices_json(){
    local mac name info connected paired class icon score key
    local -A best_mac best_score best_name best_conn best_paired best_icon

    if [ "$(controller_powered)" != "yes" ]; then
        echo "[]"
        return
    fi

    while read -r _ mac name; do
        [ -z "$mac" ] && continue
        # unnamed leftovers just render as their own address, no use pairing those
        [ "$name" = "${mac//:/-}" ] && continue

        info=$(bluetoothctl info "$mac" 2>/dev/null)
        connected=$(echo "$info" | awk '/Connected:/ {print ($2=="yes")?"true":"false"; exit}')
        paired=$(echo "$info" | awk '/Paired:/ {print ($2=="yes")?"true":"false"; exit}')
        class=$(echo "$info" | awk '/Class:/ {print $2; exit}')
        icon=$(echo "$info" | awk '/Icon:/ {print $2; exit}')
        [ -z "$connected" ] && connected="false"
        [ -z "$paired" ] && paired="false"

        score=0
        [ -n "$class" ] && score=$((score + 4))
        [ "$paired" = "true" ] && score=$((score + 2))
        [ "$connected" = "true" ] && score=$((score + 1))

        key=$(sanitize "$name")
        if [ -z "${best_score[$key]}" ] || [ "$score" -gt "${best_score[$key]}" ]; then
            best_score[$key]=$score
            best_mac[$key]=$mac
            best_name[$key]=$key
            best_conn[$key]=$connected
            best_paired[$key]=$paired
            best_icon[$key]=$(type_icon "$icon")
        fi
    done < <(bluetoothctl devices 2>/dev/null)

    # connected first, then paired, then everything else
    local out=""
    for pass in connected paired rest; do
        for key in "${!best_mac[@]}"; do
            case $pass in
                connected) [ "${best_conn[$key]}" = "true" ] || continue;;
                paired)    [ "${best_conn[$key]}" = "true" ] && continue
                           [ "${best_paired[$key]}" = "true" ] || continue;;
                rest)      [ "${best_conn[$key]}" = "true" ] && continue
                           [ "${best_paired[$key]}" = "true" ] && continue;;
            esac
            out="${out:+$out,}{\"mac\":\"${best_mac[$key]}\",\"name\":\"${best_name[$key]}\",\"icon\":\"${best_icon[$key]}\",\"connected\":${best_conn[$key]},\"paired\":${best_paired[$key]}}"
        done
    done

    echo "[$out]"
}

publish(){
    [ -x "$EWW" ] || EWW="eww"
    "$EWW" update bluetooth="$(status_json)" >/dev/null 2>&1
    "$EWW" update btdevices="$(devices_json)" >/dev/null 2>&1
}

case $1 in
  toggle)
    lock_or_exit
    if [ "$(controller_powered)" = "yes" ]; then
        btctl power off >/dev/null 2>&1
        remember_power off
    else
        rfkill unblock bluetooth >/dev/null 2>&1
        btctl power on >/dev/null 2>&1
        remember_power on
    fi
    publish
    exit 0
    ;;
  restore)
    restore_power
    publish
    exit 0
    ;;
  scan)
    [ -x "$EWW" ] || EWW="eww"

    # a second pass would just fight the running one for the adapter
    if bluetoothctl show 2>/dev/null | grep -q "Discovering: yes"; then
        exit 0
    fi

    "$EWW" update btscanning=true >/dev/null 2>&1
    timeout 45 bluetoothctl --timeout 30 scan on >/dev/null 2>&1 &

    for _ in $(seq 1 15); do
        sleep 2
        publish
    done

    wait
    "$EWW" update btscanning=false >/dev/null 2>&1
    publish
    exit 0
    ;;
  connect)
    lock_or_exit

    # an agent has to be registered for the link key to be stored, otherwise the
    # device pairs but comes back unpaired on the next disconnect
    if [ "$(btctl info "$2" 2>/dev/null | awk '/Paired:/ {print $2; exit}')" != "yes" ]; then
        btctl --agent NoInputNoOutput pair "$2" >/dev/null 2>&1 \
            || echo "bluetooth: failed to pair '$2' - put the device in pairing mode" >&2
    fi

    btctl trust "$2" >/dev/null 2>&1
    btctl connect "$2" >/dev/null 2>&1 || echo "bluetooth: failed to connect '$2'" >&2
    publish
    exit 0
    ;;
  disconnect)
    lock_or_exit
    btctl disconnect "$2" >/dev/null 2>&1
    publish
    exit 0
    ;;
  remove)
    lock_or_exit
    btctl remove "$2" >/dev/null 2>&1
    publish
    exit 0
    ;;
  devices)
    devices_json
    exit 0
    ;;
esac

status_json
