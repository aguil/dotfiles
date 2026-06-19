local repo_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))))
local nvim_config = vim.fs.joinpath(repo_root, 'dot_config', 'nvim')

vim.opt.runtimepath:prepend(nvim_config)
package.path = vim.fs.joinpath(nvim_config, 'lua', '?.lua') .. ';' .. vim.fs.joinpath(nvim_config, 'lua', '?', 'init.lua') .. ';' .. package.path

local modules = {
  'custom.vcs',
  'custom.telescope_delta',
  'custom.markdown_nav',
  'custom.plugins.ai_assistant',
  'custom.plugins.ai_cli',
  'custom.plugins.git',
  'custom.plugins.init',
  'custom.plugins.markdown',
  'custom.plugins.tmux',
  'custom.plugins.typescript',
  'custom.plugins.vale',
  'custom.plugins.web_service_dev',
  'kickstart.health',
  'kickstart.plugins.autopairs',
  'kickstart.plugins.debug',
  'kickstart.plugins.gitsigns',
  'kickstart.plugins.indent_line',
  'kickstart.plugins.lint',
  'kickstart.plugins.neo-tree',
}

local failures = {}

for _, module in ipairs(modules) do
  package.loaded[module] = nil
  local ok, err = pcall(require, module)
  if not ok then table.insert(failures, string.format('%s: %s', module, err)) end
end

if #failures > 0 then
  io.stderr:write 'Neovim Lua smoke failures:\n'
  for _, failure in ipairs(failures) do
    io.stderr:write('  - ' .. failure .. '\n')
  end
  os.exit(1)
end

print(string.format('Loaded %d Neovim Lua modules.', #modules))
os.exit(0)
