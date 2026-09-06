#!/usr/bin/env bash
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/eww"

lua - "$CFG" <<'LUA'
local cfg = assert(arg[1])
package.path = cfg .. "/lua/?.lua;" .. package.path

local tokens = require("tokens")
local stylesheet = require("style").generate()
local arch_rule = assert(stylesheet:match("%.tn%-ico%-arch%s*(%b{})"),
                         "regra visual da logo do Arch ausente")

assert(tokens.icon.arch == utf8.char(tonumber("f303", 16)),
       "o botão não usa o codepoint Nerd Font do Arch Linux")
assert(arch_rule:match('font%-family:%s*"JetBrainsMono Nerd Font"%s*;'),
       "a logo do Arch não usa a Nerd Font instalada")
assert(arch_rule:match("font%-size:%s*20px%s*;"),
       "a logo do Arch não tem o tamanho do botão original")
assert(arch_rule:match("padding:%s*0px%s+6px%s+0px%s+0px%s*;"),
       "a logo do Arch não tem a compensação óptica para a esquerda")

print("PASS: logo do Arch usa fonte, tamanho e alinhamento corretos")
LUA
