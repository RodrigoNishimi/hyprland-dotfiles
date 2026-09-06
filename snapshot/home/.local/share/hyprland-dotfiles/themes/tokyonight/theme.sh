#!/usr/bin/env bash
# Tokyo Night — https://github.com/folke/tokyonight.nvim (variante "night")
#
# Paleta do kit em new-dotfiles/README.md. É a irmã escura do
# tokyonight-moon: mesmo desenho, fundo #1a1b26 em vez de #222436.

variant="dark"

# ── Metadados ─────────────────────────────────────────────────────────────────
nvim_colorscheme="tokyonight-night"
zen_theme="nebula"
wallpaper="neon.png"
opacity="0.92"
gtk_theme=""
cursor_theme=""

# ── Camadas de fundo ──────────────────────────────────────────────────────────
base="#1a1b26"    # bg
surface="#16161e" # bg_dark
overlay="#292e42" # bg_highlight
term_bg="#101014" # black — o terminal fica um degrau abaixo do resto

# ── Realces / bordas ──────────────────────────────────────────────────────────
highlight_low="#16161e"
highlight_med="#292e42"
highlight_high="#3b4261" # terminal_black

# ── Texto ─────────────────────────────────────────────────────────────────────
muted="#565f89"  # comment
subtle="#9aa5ce" # fg_dark
text="#c0caf5"   # fg

# ── Cores ANSI (terminais) ────────────────────────────────────────────────────
black="#3b4261"   # terminal_black
red="#f7768e"
green="#9ece6a"
yellow="#e0af68"
blue="#7aa2f7"
magenta="#bb9af7"
cyan="#7dcfff"
white="#c0caf5"   # fg

bright_black="#565f89"   # comment
bright_red="#ff7a93"
bright_green="#b9f27c"
bright_yellow="#ff9e64"  # orange
bright_blue="#7da6ff"
bright_magenta="#bb9af7"
bright_cyan="#0db9d7"
bright_white="#c0caf5"

# ── Papéis de interface ───────────────────────────────────────────────────────
accent="#7aa2f7"     # blue
accent_alt="#bb9af7" # magenta
success="#9ece6a"    # green
warning="#e0af68"    # yellow
error="#f7768e"      # red
info="#2ac3de"       # blue1
