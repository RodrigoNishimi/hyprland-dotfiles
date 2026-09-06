#!/usr/bin/env bash
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/eww"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/makoctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$MAKO_CALLS"
case "${1:-}" in
    list)
        cat <<'JSON'
[{"id":10,"app_name":"Updater","app_icon":"","category":null,"desktop_entry":null,"summary":"Atualização disponível","body":"3 pacotes","urgency":"critical","actions":{}},{"id":9,"app_name":"Chat","app_icon":"chat","category":null,"desktop_entry":null,"summary":"Nova mensagem","body":"Olá <mundo>","urgency":"normal","actions":{}}]
JSON
        ;;
    history)
        cat <<'JSON'
[{"id":9,"app_name":"Chat","app_icon":"chat","category":null,"desktop_entry":null,"summary":"Nova mensagem","body":"Olá <mundo>","urgency":"normal","actions":{}},{"id":8,"app_name":"Backup","app_icon":"","category":null,"desktop_entry":null,"summary":"Concluído","body":"","urgency":"low","actions":{}}]
JSON
        ;;
    mode)
        if [[ ${2:-} == -t ]]; then exit 0; fi
        printf 'default\ndo-not-disturb\n'
        ;;
    restore|dismiss) ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$TMP/makoctl"
export MAKO_CALLS="$TMP/calls"
export PATH="$TMP:$PATH"

actual=$("$CFG/scripts/notifications.sh" status)
jq -e '
    .count == 3 and .dnd == true and
    .items[0] == {id:10, app:"Updater", summary:"Atualização disponível", body:"3 pacotes", urgency:"critical"} and
    .items[1].id == 9 and .items[2].app == "Backup"
' <<<"$actual" >/dev/null

"$CFG/scripts/notifications.sh" toggle-dnd
tail -n1 "$MAKO_CALLS" | grep -Fx 'mode -t do-not-disturb' >/dev/null

: >"$MAKO_CALLS"
"$CFG/scripts/notifications.sh" clear
expected=$'dismiss --all --no-history\nhistory -j\nrestore\ndismiss --no-history\nrestore\ndismiss --no-history'
[[ $(cat "$MAKO_CALLS") == "$expected" ]]

echo 'PASS: notification state, DND toggle and history cleanup'
