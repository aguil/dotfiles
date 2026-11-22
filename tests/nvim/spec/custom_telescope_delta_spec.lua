local function reload_telescope_delta()
  package.loaded['custom.telescope_delta'] = nil
  return require 'custom.telescope_delta'
end

describe('custom.telescope_delta', function()
  it('runs delta diff pipelines with a non-login sh -c shell', function()
    local delta = reload_telescope_delta()
    local bufnr = vim.api.nvim_create_buf(false, true)

    local original_jobstart = vim.fn.jobstart
    local captured_cmd, captured_opts
    vim.fn.jobstart = function(cmd, opts)
      captured_cmd = cmd
      captured_opts = opts
      return 0
    end

    local ok, err = pcall(function() delta.termopen_diff(bufnr, '/repo', { 'git', 'diff', '--no-color', 'HEAD', '--', 'README.md' }) end)

    vim.fn.jobstart = original_jobstart
    if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_delete(bufnr, { force = true }) end
    if not ok then error(err, 0) end

    asserts.equals('sh', captured_cmd[1])
    asserts.equals('-c', captured_cmd[2])
    asserts.truthy(captured_cmd[3]:find('delta', 1, true))
    asserts.equals('/repo', captured_opts.cwd)
    asserts.truthy(captured_opts.term)
  end)

  it('caches resolved executable paths to avoid repeated PATH walks', function()
    local delta = reload_telescope_delta()
    local bufnr = vim.api.nvim_create_buf(false, true)

    local original_jobstart = vim.fn.jobstart
    local original_exepath = vim.fn.exepath
    local exepath_calls = {}
    local captured_cmds = {}

    vim.fn.exepath = function(name)
      exepath_calls[name] = (exepath_calls[name] or 0) + 1
      if name == 'jj' then return '/opt/bin/jj' end
      if name == 'delta' then return '/opt/bin/delta' end
      return ''
    end
    vim.fn.jobstart = function(cmd)
      table.insert(captured_cmds, cmd)
      return 0
    end

    local ok, err = pcall(function()
      delta.termopen_diff(bufnr, '/repo', { 'jj', '--ignore-working-copy', 'diff' })
      delta.termopen_diff(bufnr, '/repo', { 'jj', '--ignore-working-copy', 'diff' })
    end)

    vim.fn.jobstart = original_jobstart
    vim.fn.exepath = original_exepath
    if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_delete(bufnr, { force = true }) end
    if not ok then error(err, 0) end

    asserts.equals(1, exepath_calls.jj)
    asserts.equals(1, exepath_calls.delta)
    asserts.truthy(captured_cmds[1][3]:find('/opt/bin/jj', 1, true))
    asserts.truthy(captured_cmds[1][3]:find('/opt/bin/delta', 1, true))
  end)
end)
