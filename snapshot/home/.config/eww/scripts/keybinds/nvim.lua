local rows = {}
local function add(mode, maps, context)
  for _, m in ipairs(maps) do
    if not m.lhs:match('^<Plug>') and not m.lhs:match('^<SNR>') then
      local desc = m.desc or m.rhs or ''
      local source = context
      if m.callback and type(m.callback) == 'function' then
        local info = debug.getinfo(m.callback, 'S')
        source = info.source:gsub('^@', '') .. ':' .. info.linedefined
        if desc == '' and vim.fn.filereadable((info.source:gsub('^@', ''))) == 1 then
          local lines = vim.fn.readfile((info.source:gsub('^@', '')))
          desc = table.concat(vim.list_slice(lines, info.linedefined, info.lastlinedefined), ' ')
        end
      end
      rows[#rows+1] = {section='Nvim', context=context .. ' · ' .. mode,
        key=m.lhs:gsub('^ ', 'Espaço → '), description=desc, source=source}
    end
  end
end
for _, mode in ipairs({'n','i','x','s','o','c','t'}) do add(mode, vim.api.nvim_get_keymap(mode), 'Global') end
vim.api.nvim_exec_autocmds('LspAttach', {group='Lsp', buffer=0})
for _, mode in ipairs({'n','i','x'}) do add(mode, vim.api.nvim_buf_get_keymap(0, mode), 'LSP · buffer') end
local ok, oil = pcall(require, 'oil.config')
if ok then
  for key, v in pairs(oil.keymaps) do
    if v ~= false then
      rows[#rows+1] = {section='Nvim', context='Oil · n', key=key,
        description=type(v)=='string' and v or (v.desc or v[1] or 'Callback Oil'), source='oil.config'}
    end
  end
end
vim.fn.writefile({vim.json.encode(rows)}, vim.env.KEYBINDS_NVIM_OUTPUT)
vim.cmd('qa!')
