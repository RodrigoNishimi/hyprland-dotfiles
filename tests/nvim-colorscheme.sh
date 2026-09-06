#!/usr/bin/env bash
set -euo pipefail

output=$(nvim --headless \
    "+lua assert(vim.g.colors_name == 'tokyonight-night', 'esperado tokyonight-night, obtido ' .. tostring(vim.g.colors_name))" \
    '+qa' 2>&1)

if [[ -n $output ]]; then
    printf '%s\n' "$output" >&2
    exit 1
fi

echo 'PASS: Neovim inicia com tokyonight-night sem avisos'
