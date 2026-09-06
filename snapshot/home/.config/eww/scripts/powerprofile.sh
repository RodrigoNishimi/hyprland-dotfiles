#!/bin/bash

# Power profile control for the user panel.
#   ./powerprofile.sh           -> print the active profile as JSON (defpoll)
#   ./powerprofile.sh cycle     -> switch to the next profile
#   ./powerprofile.sh set NAME  -> switch to a specific profile
#
# Stateless on purpose: eww never restarts a deflisten that exits, so a
# long-running listener would freeze the panel on its last value. A defpoll
# re-runs this on every interval and always recovers.

EWW="/usr/bin/eww"
BUS="net.hadess.PowerProfiles"
BUS_PATH="/net/hadess/PowerProfiles"

get_active(){
  local profile
  profile=$(busctl --system get-property "$BUS" "$BUS_PATH" "$BUS" ActiveProfile 2>/dev/null \
            | sed -E 's/^s "(.*)"$/\1/')
  [ -z "$profile" ] && profile=$(powerprofilesctl get 2>/dev/null)
  [ -z "$profile" ] && profile="none"
  echo "$profile"
}

get_profiles(){
  local list
  list=$(powerprofilesctl list 2>/dev/null | grep -E '^\*?[[:space:]]*[a-z-]+:$' | tr -d '* :')
  [ -z "$list" ] && list=$'performance\nbalanced\npower-saver'
  echo "$list"
}

get_json(){
  case $1 in
    performance)
      ICON="󰓅"
      LABEL="Performance"
      SHORT="Perf"
      CLASS="pp-performance"
      ;;
    power-saver)
      ICON="󰌪"
      LABEL="Power Saver"
      SHORT="Saver"
      CLASS="pp-powersaver"
      ;;
    balanced)
      ICON="󰾅"
      LABEL="Balanced"
      SHORT="Bal"
      CLASS="pp-balanced"
      ;;
    *)
      ICON="󰾆"
      LABEL="Unavailable"
      SHORT="n/a"
      CLASS="pp-off"
      ;;
  esac

  echo "{\"profile\": \"$1\", \"icon\": \"$ICON\", \"label\": \"$LABEL\", \"short\": \"$SHORT\", \"class\": \"$CLASS\"}"
}

# Push the profile the daemon really ended up on, so the panel never shows a
# switch that did not happen (power-profiles-daemon can refuse or downgrade one).
publish(){
    [ -x "$EWW" ] || EWW="eww"
    "$EWW" update powerprofile="$(get_json "$(get_active)")" >/dev/null 2>&1
}

apply(){
    if ! powerprofilesctl set "$1" 2>&1; then
        echo "powerprofile: failed to set '$1'" >&2
    fi
    publish
}

case $1 in
  cycle)
    mapfile -t PROFILES < <(get_profiles)
    CURRENT=$(get_active)
    NEXT=${PROFILES[0]}

    for i in "${!PROFILES[@]}"; do
      if [[ "${PROFILES[$i]}" == "$CURRENT" ]]; then
        NEXT=${PROFILES[$(( (i + 1) % ${#PROFILES[@]} ))]}
        break
      fi
    done

    apply "$NEXT"
    exit 0
    ;;
  set)
    apply "$2"
    exit 0
    ;;
esac

get_json "$(get_active)"
