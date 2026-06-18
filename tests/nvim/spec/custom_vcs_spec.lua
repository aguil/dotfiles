local function reload_vcs()
  package.loaded['custom.vcs'] = nil
  return require 'custom.vcs'
end

local function temp_dir()
  local base = vim.fs.normalize(vim.fn.tempname())
  vim.fn.mkdir(base, 'p')
  return base
end

local function mkdir(path) vim.fn.mkdir(path, 'p') end

local function write_file(path, lines) vim.fn.writefile(lines or { '' }, path) end

local function command_key(cmd) return table.concat(cmd, ' ') end

local function with_fake_system(responses, fn)
  local original_system = vim.system
  local calls = {}

  vim.system = function(cmd, opts)
    table.insert(calls, { cmd = cmd, opts = opts })
    local response = responses[command_key(cmd)] or { stdout = '', code = 1 }
    return {
      wait = function() return response end,
    }
  end

  local ok, err = pcall(fn, calls)
  vim.system = original_system
  if not ok then error(err, 0) end
end

describe('custom.vcs', function()
  before_each(function() vim.g.dot_vcs_default_branches = nil end)

  it('finds a Git root by walking up from a file', function()
    local root = temp_dir()
    mkdir(vim.fs.joinpath(root, '.git'))
    mkdir(vim.fs.joinpath(root, 'nested'))
    local file = vim.fs.joinpath(root, 'nested', 'file.lua')
    write_file(file)

    local vcs = reload_vcs()

    asserts.equals(root, vcs.find_root(file))
    vim.fn.delete(root, 'rf')
  end)

  it('prefers jj when a workspace is colocated with Git', function()
    local root = temp_dir()
    mkdir(vim.fs.joinpath(root, '.git'))
    mkdir(vim.fs.joinpath(root, '.jj'))

    local vcs = reload_vcs()

    asserts.equals('jj', vcs.workspace_kind_for_path(root))
    vim.fn.delete(root, 'rf')
  end)

  it('returns paths relative to the repository root', function()
    local vcs = reload_vcs()

    asserts.equals('lua/custom/vcs.lua', vcs.relative_path('/repo/lua/custom/vcs.lua', '/repo'))
    asserts.falsy(vcs.relative_path('/other/lua/custom/vcs.lua', '/repo'))
  end)

  it('uses configured default branch candidates for Git labels', function()
    local vcs = reload_vcs()
    vim.g.dot_vcs_default_branches = { 'trunk', 'main' }

    with_fake_system({
      ['git symbolic-ref --quiet --short refs/remotes/origin/HEAD'] = {
        stdout = '',
        code = 1,
      },
      ['git rev-parse --verify --quiet trunk'] = { stdout = '', code = 1 },
      ['git rev-parse --verify --quiet origin/trunk'] = {
        stdout = '',
        code = 1,
      },
      ['git rev-parse --verify --quiet main'] = { stdout = '', code = 0 },
    }, function() asserts.equals('main...HEAD', vcs.diff_range_label('git', '/repo')) end)
  end)

  it('uses origin HEAD when Git exposes it', function()
    local vcs = reload_vcs()

    with_fake_system({
      ['git symbolic-ref --quiet --short refs/remotes/origin/HEAD'] = {
        stdout = 'origin/master\n',
        code = 0,
      },
    }, function()
      asserts.equals('origin/master', vcs.find_git_default_branch '/repo')
      asserts.equals('origin/master...HEAD', vcs.diff_range_label('git', '/repo'))
    end)
  end)

  it('builds working-copy diff commands without resolving the default branch', function()
    local vcs = reload_vcs()
    vcs.base_mode = 'working_copy'

    asserts.same({ 'git', 'diff', '--no-color', '--name-only', 'HEAD' }, vcs.branch_name_only_cmd('git', '/repo'))
    asserts.same({ 'git', 'diff', '--no-color', 'HEAD', '--', 'lua/custom/vcs.lua' }, vcs.file_branch_diff_cmd('git', '/repo', 'lua/custom/vcs.lua'))
    asserts.equals('HEAD (working tree)', vcs.diff_range_label('git', '/repo'))
  end)

  it('builds jj diff commands from the active base mode', function()
    local vcs = reload_vcs()
    vcs.base_mode = 'working_copy'

    asserts.same({ 'jj', '--color', 'never', 'diff', '--name-only', '-r', '@-..@' }, vcs.branch_name_only_cmd('jj', '/repo'))
    asserts.same({
      'jj',
      '--color',
      'never',
      'diff',
      '--git',
      '-r',
      '@-..@',
      '--',
      'lua/custom/vcs.lua',
    }, vcs.file_branch_diff_cmd('jj', '/repo', 'lua/custom/vcs.lua'))
    asserts.equals('@-..@', vcs.diff_range_label('jj', '/repo'))
  end)
end)
