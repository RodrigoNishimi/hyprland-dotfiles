#!/usr/bin/env bash
exec "$(dirname "$0")/panel.sh" calendar "${1:-toggle}"
