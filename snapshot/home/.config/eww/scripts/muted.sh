#!/usr/bin/env bash
mute=$(pamixer --get-mute 2>/dev/null)
if [[ $mute == true ]]; then echo true; else echo false; fi
