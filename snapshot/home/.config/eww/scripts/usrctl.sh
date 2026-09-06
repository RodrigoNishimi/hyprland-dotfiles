#!/usr/bin/env bash
exec "$(dirname "$0")/panel.sh" usrctl "${1:-toggle}"
