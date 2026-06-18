--- Git/jj workspace helpers and shared diff-base toggle state.
local M = {}

---@type 'default_branch'|'working_copy'
M.base_mode = 'default_branch'

local function parent_dir(p)
  local next_parent = vim.fs.dirname(p)
  if next_parent == p then return nil end
  return next_parent
end

local function system_result(cmd, cwd)
  local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
  local stdout = result.stdout or ''
  if stdout:sub(-1) == '\n' then stdout = stdout:sub(1, -2) end
  return stdout, result.code
end

function M.system_ok(cmd, cwd)
  local _, code = system_result(cmd, cwd)
  return code == 0
end

function M.default_branch_candidates() return vim.g.dot_vcs_default_branches or { 'master', 'main' } end

--- Walk upward from `path` to the first directory containing `.git` or `.jj`.
--- @param path string file or directory path
--- @return string|nil
function M.find_root(path)
  path = vim.fs.normalize(path)
  local stat = vim.uv.fs_stat(path)
  if stat and stat.type ~= 'directory' then path = vim.fs.dirname(path) end
  while path do
    if vim.uv.fs_stat(path .. '/.git') or vim.uv.fs_stat(path .. '/.jj') then return path end
    path = parent_dir(path)
  end
  return nil
end

--- @param path string|nil
--- @return 'git'|'jj'|'none'
function M.workspace_kind_for_path(path)
  local root = M.find_root(path or vim.fn.getcwd(0))
  if not root then return 'none' end
  if vim.uv.fs_stat(root .. '/.jj') then return 'jj' end
  if vim.uv.fs_stat(root .. '/.git') then return 'git' end
  return 'none'
end

--- When both `.jj` and `.git` exist (colocated), prefer `jj`.
--- @param bufnr integer
--- @return 'git'|'jj'|'none'
function M.workspace_kind(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local path
  if name ~= '' then
    path = vim.fs.dirname(vim.fs.normalize(name))
  else
    path = vim.fn.getcwd(0)
  end
  return M.workspace_kind_for_path(path)
end

function M.find_git_default_branch(root)
  local stdout, code = system_result({
    'git',
    'symbolic-ref',
    '--quiet',
    '--short',
    'refs/remotes/origin/HEAD',
  }, root)
  if code == 0 and stdout ~= '' then return stdout end

  for _, branch in ipairs(M.default_branch_candidates()) do
    if M.system_ok({ 'git', 'rev-parse', '--verify', '--quiet', branch }, root) then return branch end
    if M.system_ok({ 'git', 'rev-parse', '--verify', '--quiet', 'origin/' .. branch }, root) then return 'origin/' .. branch end
  end
end

function M.find_jj_default_branch(root)
  for _, branch in ipairs(M.default_branch_candidates()) do
    if
      M.system_ok({
        'jj',
        'log',
        '--no-graph',
        '--limit',
        '1',
        '-r',
        branch,
        '-T',
        'commit_id',
      }, root)
    then
      return branch
    end
    local remote_branch = branch .. '@origin'
    if
      M.system_ok({
        'jj',
        'log',
        '--no-graph',
        '--limit',
        '1',
        '-r',
        remote_branch,
        '-T',
        'commit_id',
      }, root)
    then
      return remote_branch
    end
  end
end

function M.base_mode_label() return M.base_mode == 'working_copy' and 'working copy' or 'default branch' end

function M.resolve_jj_signs_base(root)
  if M.base_mode == 'working_copy' then return '@-' end
  return M.find_jj_default_branch(root) or '@-'
end

--- Revision range / ref label for diffs in the current base mode.
--- @return string|nil
function M.diff_range_label(kind, root)
  if kind == 'jj' then
    if M.base_mode == 'working_copy' then return '@-..@' end
    local base = M.find_jj_default_branch(root) or '@-'
    return base .. '..@'
  end

  if kind == 'git' then
    if M.base_mode == 'working_copy' then return 'HEAD (working tree)' end
    local base = M.find_git_default_branch(root)
    if not base then return nil end
    return base .. '...HEAD'
  end

  return nil
end

--- Range string for listing or diffing branch/working-copy changes.
--- @return string|nil
function M.resolve_diff_range(kind, root) return M.diff_range_label(kind, root) end

function M.relative_path(filepath, root)
  filepath = vim.fs.normalize(filepath)
  root = vim.fs.normalize(root)
  if vim.startswith(filepath, root .. '/') then return filepath:sub(#root + 2) end
  return nil
end

local function git_untracked_diff_cmd(filepath)
  if not vim.uv.fs_stat(filepath) then return nil end
  return { 'git', '--no-pager', 'diff', '--no-index', '/dev/null', filepath }
end

local function git_tracked_has_diff(root, rel, range_or_head)
  if M.base_mode == 'working_copy' then return not M.system_ok({ 'git', '-C', root, 'diff', '--quiet', 'HEAD', '--', rel }, root) end
  return not M.system_ok({ 'git', '-C', root, 'diff', '--quiet', range_or_head, '--', rel }, root)
end

local function jj_has_diff(root, range, relpath)
  local stdout, code = system_result({
    'jj',
    '--color',
    'never',
    'diff',
    '--name-only',
    '-r',
    range,
    '--',
    relpath,
  }, root)
  return code == 0 and stdout ~= ''
end

--- @class vcs.FileDiffSpec
--- @field cmd string[]
--- @field cwd string
--- @field label string

local function jj_diff_cmd(range, relpath, context)
  local cmd = { 'jj', '--color', 'never', 'diff', '--git' }
  if context then vim.list_extend(cmd, { '--context', tostring(context) }) end
  vim.list_extend(cmd, { '-r', range, '--', relpath })
  return cmd
end

local function git_diff_cmd(diff_args, relpath, context)
  local cmd = { 'git', '--no-pager', 'diff', '--no-color' }
  if context then vim.list_extend(cmd, { '-U', tostring(context) }) end
  vim.list_extend(cmd, diff_args)
  table.insert(cmd, '--')
  table.insert(cmd, relpath)
  return cmd
end

local function git_diff_cmd(diff_args, relpath, context)
  local cmd = { 'git', '--no-pager', 'diff', '--no-color' }
  if context then vim.list_extend(cmd, { '-U', tostring(context) }) end
  vim.list_extend(cmd, diff_args)
  table.insert(cmd, '--')
  table.insert(cmd, relpath)
  return cmd
end

local diff_cache = {
  has = {},
  spec = {},
}

function M.clear_file_diff_cache()
  diff_cache.has = {}
  diff_cache.spec = {}
end

--- @class vcs.FileRef
--- @field filepath string
--- @field root string
--- @field kind 'git'|'jj'
--- @field relpath string
--- @field label string

--- @return vcs.FileRef|nil
local function resolve_file(filepath)
  if not filepath or filepath == '' then return nil end

  filepath = vim.fs.normalize(filepath)
  local root = M.find_root(filepath)
  if not root then return nil end

  local kind = M.workspace_kind_for_path(filepath)
  if kind == 'none' then return nil end

  local relpath = M.relative_path(filepath, root)
  if not relpath then return nil end

  local label = M.diff_range_label(kind, root)
  if not label then return nil end

  return {
    filepath = filepath,
    root = root,
    kind = kind,
    relpath = relpath,
    label = label,
  }
end

local function has_cache_key(ref) return ref.root .. '\0' .. ref.relpath .. '\0' .. ref.kind .. '\0' .. M.base_mode end

--- @param ref vcs.FileRef
local function file_has_diff_ref(ref)
  local key = has_cache_key(ref)
  if diff_cache.has[key] ~= nil then return diff_cache.has[key] end

  local has = false
  if ref.kind == 'jj' then
    if vim.fn.executable 'jj' == 1 then
      local range = M.resolve_diff_range('jj', ref.root)
      has = range ~= nil and jj_has_diff(ref.root, range, ref.relpath)
    end
  elseif vim.fn.executable 'git' == 1 then
    local tracked = M.system_ok({
      'git',
      '-C',
      ref.root,
      'ls-files',
      '--error-unmatch',
      '--',
      ref.relpath,
    }, ref.root)
    if tracked then
      local range = M.resolve_diff_range('git', ref.root)
      if range then
        local diff_ref = M.base_mode == 'working_copy' and 'HEAD' or range
        has = git_tracked_has_diff(ref.root, ref.relpath, diff_ref)
      end
    elseif M.base_mode == 'working_copy' then
      has = git_untracked_diff_cmd(ref.filepath) ~= nil
    end
  end

  diff_cache.has[key] = has
  return has
end

--- Whether `filepath` has a diff for the active base mode.
--- @param filepath string
--- @param opts? { cwd?: string }
function M.file_has_diff(filepath, opts)
  opts = opts or {}
  local ref = resolve_file(filepath)
  if not ref then return false end
  return file_has_diff_ref(ref)
end

--- Build a per-file diff command when the file differs for the active base mode.
--- @param filepath string
--- @param opts? { cwd?: string, context?: integer }
--- @return vcs.FileDiffSpec|nil
function M.file_diff_spec(filepath, opts)
  opts = opts or {}
  local ref = resolve_file(filepath)
  if not ref or not file_has_diff_ref(ref) then return nil end

  local context = opts.context
  local spec_key = has_cache_key(ref) .. '\0' .. tostring(context or '')
  local cached = diff_cache.spec[spec_key]
  if cached ~= nil then return cached == false and nil or cached end

  local spec
  if ref.kind == 'jj' then
    local range = M.resolve_diff_range('jj', ref.root)
    spec = {
      cmd = jj_diff_cmd(range, ref.relpath, context),
      cwd = ref.root,
      label = ref.label,
    }
  elseif M.base_mode == 'working_copy' then
    local tracked = M.system_ok({
      'git',
      '-C',
      ref.root,
      'ls-files',
      '--error-unmatch',
      '--',
      ref.relpath,
    }, ref.root)
    if tracked then
      spec = {
        cmd = git_diff_cmd({ 'HEAD' }, ref.relpath, context),
        cwd = ref.root,
        label = ref.label,
      }
    else
      spec = {
        cmd = git_untracked_diff_cmd(ref.filepath),
        cwd = ref.root,
        label = ref.label,
      }
    end
  else
    local range = M.resolve_diff_range('git', ref.root)
    spec = {
      cmd = git_diff_cmd({ range }, ref.relpath, context),
      cwd = ref.root,
      label = ref.label,
    }
  end

  diff_cache.spec[spec_key] = spec or false
  return spec
end

--- Command to list changed paths for the branch-changes picker.
--- @return string[]|nil
function M.branch_name_only_cmd(kind, root)
  if kind == 'jj' then
    local range = M.resolve_diff_range('jj', root)
    if not range then return nil end
    return { 'jj', '--color', 'never', 'diff', '--name-only', '-r', range }
  end

  if kind == 'git' then
    if M.base_mode == 'working_copy' then return { 'git', 'diff', '--no-color', '--name-only', 'HEAD' } end
    local base = M.find_git_default_branch(root)
    if not base then return nil end
    return { 'git', 'diff', '--no-color', '--name-only', base .. '...HEAD' }
  end

  return nil
end

--- Per-file diff command for the branch-changes picker preview.
--- @return string[]|nil
function M.file_branch_diff_cmd(kind, root, relpath)
  if kind == 'jj' then
    local range = M.resolve_diff_range('jj', root)
    if not range then return nil end
    return {
      'jj',
      '--color',
      'never',
      'diff',
      '--git',
      '-r',
      range,
      '--',
      relpath,
    }
  end

  if kind == 'git' then
    if M.base_mode == 'working_copy' then return { 'git', 'diff', '--no-color', 'HEAD', '--', relpath } end
    local range = M.resolve_diff_range('git', root)
    if not range then return nil end
    return { 'git', 'diff', '--no-color', range, '--', relpath }
  end

  return nil
end

function M.toggle_base_mode()
  M.base_mode = M.base_mode == 'default_branch' and 'working_copy' or 'default_branch'
  M.clear_file_diff_cache()

  local bufname = vim.api.nvim_buf_get_name(0)
  local path = bufname ~= '' and vim.fs.normalize(bufname) or vim.fn.getcwd(0)
  local root = M.find_root(path)
  local kind = root and M.workspace_kind_for_path(path) or 'none'

  if M.base_mode == 'default_branch' and root then
    if kind == 'jj' and not M.find_jj_default_branch(root) then
      vim.notify('Could not find default branch. Falling back to @-. Set vim.g.dot_vcs_default_branches.', vim.log.levels.WARN)
    elseif kind == 'git' and not M.find_git_default_branch(root) then
      vim.notify('Could not find default branch. Set vim.g.dot_vcs_default_branches.', vim.log.levels.WARN)
    end
  end

  if kind == 'jj' then
    local ok = pcall(function()
      require('jjsigns.config').config.base = M.resolve_jj_signs_base(root)
      require('jjsigns.attach').refresh_all()
    end)
    if not ok then
      -- jjsigns not loaded yet; telescope previews still honor base_mode.
    end
  end

  local range = root and M.diff_range_label(kind, root) or nil
  local detail = range and (' (' .. range .. ')') or ''
  vim.notify('Diff base: ' .. M.base_mode_label() .. detail)
end

return M
