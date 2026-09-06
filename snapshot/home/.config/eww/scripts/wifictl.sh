#!/usr/bin/env bash
exec "$(dirname "$0")/panel.sh" wifictl "${1:-toggle}"
