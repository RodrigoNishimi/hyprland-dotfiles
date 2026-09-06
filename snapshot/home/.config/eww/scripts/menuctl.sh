#!/usr/bin/env bash
exec "$(dirname "$0")/panel.sh" menuctl "${1:-toggle}"
