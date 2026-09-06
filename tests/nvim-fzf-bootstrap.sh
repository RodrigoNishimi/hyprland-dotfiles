#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_plugins="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/core/opt"
fzf_source="$source_plugins/telescope-fzf-native.nvim"
[[ -d $fzf_source ]] || { echo "SKIP: telescope-fzf-native.nvim source is unavailable"; exit 0; }

test_root=$(mktemp -d /tmp/nvim-fzf-test-XXXXXXXX)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/home/.config" "$test_root/home/.local/share/nvim/site/pack/core/opt"
cp -a "$repo/snapshot/home/.config/nvim" "$test_root/home/.config/nvim"
cp -a "$repo/snapshot/home/plugins" "$test_root/home/plugins"

cp -a --reflink=auto "$source_plugins/." "$test_root/home/.local/share/nvim/site/pack/core/opt/"
rm -rf "$test_root/home/.local/share/nvim/site/pack/core/opt/telescope-fzf-native.nvim/build"

output=$(HOME="$test_root/home" \
    XDG_CONFIG_HOME="$test_root/home/.config" \
    XDG_DATA_HOME="$test_root/home/.local/share" \
    XDG_STATE_HOME="$test_root/home/.local/state" \
    XDG_CACHE_HOME="$test_root/home/.cache" \
    nvim --headless "+lua assert(package.loaded['telescope._extensions.fzf'], 'extensão FZF não carregada')" '+qa' 2>&1) || {
        printf '%s\n' "$output" >&2
        exit 1
    }

[[ -f $test_root/home/.local/share/nvim/site/pack/core/opt/telescope-fzf-native.nvim/build/libfzf.so ]]
[[ -z $output ]]
echo 'PASS: Neovim compiles and loads an unbuilt Telescope FZF plugin'
