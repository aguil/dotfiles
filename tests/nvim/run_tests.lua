local repo_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))))
local nvim_config = vim.fs.joinpath(repo_root, 'dot_config', 'nvim')
local spec_dir = vim.fs.joinpath(repo_root, 'tests', 'nvim', 'spec')

vim.opt.runtimepath:prepend(nvim_config)
package.path = table.concat({
  vim.fs.joinpath(nvim_config, 'lua', '?.lua'),
  vim.fs.joinpath(nvim_config, 'lua', '?', 'init.lua'),
  vim.fs.joinpath(spec_dir, '?.lua'),
  package.path,
}, ';')

local total = 0
local failures = {}
local before_each_stack = {}

local function fail(message) error(message, 2) end

local function render(value)
  if type(value) == 'string' then return string.format('%q', value) end
  return vim.inspect(value)
end

local function deep_equal(left, right) return vim.deep_equal(left, right) end

_G.asserts = {
  equals = function(expected, actual)
    if actual ~= expected then fail(string.format('expected %s, got %s', render(expected), render(actual))) end
  end,
  same = function(expected, actual)
    if not deep_equal(actual, expected) then fail(string.format('expected %s, got %s', render(expected), render(actual))) end
  end,
  truthy = function(actual)
    if not actual then fail(string.format('expected truthy value, got %s', render(actual))) end
  end,
  falsy = function(actual)
    if actual then fail(string.format('expected falsy value, got %s', render(actual))) end
  end,
}

_G.describe = function(name, fn)
  print(name)
  table.insert(before_each_stack, {})
  local ok, err = pcall(fn)
  table.remove(before_each_stack)
  if not ok then table.insert(failures, { name = name, err = err }) end
end

_G.before_each = function(fn) table.insert(before_each_stack[#before_each_stack], fn) end

_G.it = function(name, fn)
  total = total + 1
  local ok, err = pcall(function()
    for _, callbacks in ipairs(before_each_stack) do
      for _, callback in ipairs(callbacks) do
        callback()
      end
    end
    fn()
  end)

  if ok then
    print('  ok - ' .. name)
  else
    print('  not ok - ' .. name)
    table.insert(failures, { name = name, err = err })
  end
end

local specs = vim.fn.glob(vim.fs.joinpath(spec_dir, '*_spec.lua'), false, true)
table.sort(specs)

if #specs == 0 then
  io.stderr:write('No Neovim Lua specs found in ' .. spec_dir .. '\n')
  os.exit(1)
end

for _, spec in ipairs(specs) do
  dofile(spec)
end

if #failures > 0 then
  io.stderr:write(string.format('\n%d of %d Neovim Lua tests failed:\n', #failures, total))
  for _, failure in ipairs(failures) do
    io.stderr:write(string.format('  - %s: %s\n', failure.name, failure.err))
  end
  os.exit(1)
end

print(string.format('\n%d Neovim Lua tests passed.', total))
os.exit(0)
