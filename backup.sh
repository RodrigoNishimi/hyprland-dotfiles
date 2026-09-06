#!/usr/bin/env bash
# Explicit backup or refresh of the versioned snapshot. Never pushes to GitHub.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case "${1:-}" in
    '')
        destination="$repo/backups/$(date +%Y%m%d-%H%M%S)"
        python3 "$repo/manage.py" capture --output "$destination"
        ;;
    --update)
        command -v rsync >/dev/null || { echo 'Install rsync first.' >&2; exit 1; }
        destination=$(mktemp -d "$repo/.capture-XXXXXXXX")
        python3 "$repo/manage.py" capture --output "$destination/snapshot"
        rsync -a --delete -- "$destination/snapshot/" "$repo/snapshot/"
        echo 'Snapshot updated. Review git diff, then commit and push. Temporary capture retained in:'
        echo "$destination"
        ;;
    *) echo 'Usage: ./backup.sh [--update]'; exit 2 ;;
esac
