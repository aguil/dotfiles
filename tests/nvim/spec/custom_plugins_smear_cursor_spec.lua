local function smear_spec()
  package.loaded['custom.plugins.smear_cursor'] = nil
  return require('custom.plugins.smear_cursor')[1]
end

local function with_env(vars, fn)
  local previous = {}
  for key in pairs(vars) do
    previous[key] = vim.env[key]
    vim.env[key] = vars[key] ~= '' and vars[key] or nil
  end

  local ok, err = pcall(fn)
  for key in pairs(vars) do
    vim.env[key] = previous[key]
  end
  if not ok then error(err, 0) end
end

local function with_tmux_client(termname, fn)
  local original_executable = vim.fn.executable
  local original_systemlist = vim.fn.systemlist
  vim.fn.executable = function(name)
    if name == 'tmux' then return 1 end
    return original_executable(name)
  end
  vim.fn.systemlist = function() return { termname } end

  local ok, err = pcall(fn)
  vim.fn.executable = original_executable
  vim.fn.systemlist = original_systemlist
  if not ok then error(err, 0) end
end

describe('custom.plugins.smear_cursor', function()
  it('loads outside Ghostty', function()
    with_env({ TMUX = '', TERM = 'xterm-256color', TERM_PROGRAM = '' }, function() asserts.equals(true, smear_spec().cond()) end)
  end)

  it('skips under Ghostty without tmux', function()
    with_env({ TMUX = '', TERM = 'xterm-ghostty', TERM_PROGRAM = 'ghostty' }, function() asserts.equals(false, smear_spec().cond()) end)
  end)

  it('skips over ssh from Ghostty, where only TERM is forwarded', function()
    with_env({ TMUX = '', TERM = 'xterm-ghostty', TERM_PROGRAM = '' }, function() asserts.equals(false, smear_spec().cond()) end)
  end)

  it('skips when the attached tmux client is Ghostty', function()
    with_env({ TMUX = '/tmp/tmux-1000/default,1,0', TERM = 'tmux-256color', TERM_PROGRAM = 'tmux' }, function()
      with_tmux_client('xterm-ghostty', function() asserts.equals(false, smear_spec().cond()) end)
    end)
  end)

  it('loads when the attached tmux client is not Ghostty, even with stale Ghostty env', function()
    with_env({
      TMUX = '/tmp/tmux-1000/default,1,0',
      TERM = 'tmux-256color',
      TERM_PROGRAM = 'tmux',
      GHOSTTY_RESOURCES_DIR = '/Applications/Ghostty.app/Contents/Resources/ghostty',
    }, function()
      with_tmux_client('xterm-256color', function() asserts.equals(true, smear_spec().cond()) end)
    end)
  end)
end)
