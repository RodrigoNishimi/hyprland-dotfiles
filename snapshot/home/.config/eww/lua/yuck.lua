-- ==================================================================
-- Escritor mínimo de yuck: nós viram s-expressões indentadas.
--
--   node("box", { "class", "tn-bar", "orientation", "h" }, filho, ...)
--
-- Os atributos vêm numa lista plana (chave, valor, chave, valor) só
-- porque tabela de Lua não guarda ordem — e a ordem dos `:props` é o
-- que faz o yuck gerado continuar legível.
-- ==================================================================
local Y = {}

local RawMT = { __tostring = function(r) return r[1] end }

--- Valor que entra no yuck como está: `{expressões}`, números, `true`.
function Y.raw(text) return setmetatable({ text }, RawMT) end

local function isRaw(v) return getmetatable(v) == RawMT end

local function quote(s)
    return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function value(v)
    if isRaw(v) then return v[1] end
    if type(v) == "string" then return quote(v) end
    return tostring(v)
end

function Y.node(tag, attrs, ...)
    return { tag = tag, attrs = attrs or {}, kids = { ... } }
end

--- Bloco solto (comentário, defpoll escrito à mão) copiado sem toque.
function Y.verbatim(text) return { verbatim = text } end

local function renderAttrs(attrs)
    local out = {}
    for i = 1, #attrs, 2 do
        out[#out + 1] = (":%s %s"):format(attrs[i], value(attrs[i + 1]))
    end
    return table.concat(out, " ")
end

function Y.render(node, indent)
    indent = indent or ""
    if node.verbatim then return node.verbatim end

    local head = "(" .. node.tag
    local attrs = renderAttrs(node.attrs)
    if attrs ~= "" then head = head .. " " .. attrs end

    if #node.kids == 0 then return indent .. head .. ")" end

    local lines = { indent .. head }
    for _, kid in ipairs(node.kids) do
        lines[#lines + 1] = Y.render(kid, indent .. "    ")
    end
    lines[#lines] = lines[#lines] .. ")"
    return table.concat(lines, "\n")
end

--- `(defwidget nome [args] corpo)`
function Y.widget(name, args, ...)
    local head = ("(defwidget %s [%s]"):format(name, table.concat(args, " "))
    local lines = { head }
    for _, kid in ipairs({ ... }) do
        lines[#lines + 1] = Y.render(kid, "    ")
    end
    lines[#lines] = lines[#lines] .. ")"
    return table.concat(lines, "\n")
end

return Y
