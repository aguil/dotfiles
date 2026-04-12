--- Detect Git vs jj-only repository roots for keymap dispatch.
local M = {}

local function parent_dir(p)
  local next_parent = vim.fs.dirname(p)
  if next_parent == p then
    return nil
  end
  return next_parent
end

--- Walk upward from `path` to the first directory containing `.git` or `.jj`.
--- @param path string file or directory path
--- @return string|nil
function M.find_root(path)
  path = vim.fs.normalize(path)
  local stat = vim.uv.fs_stat(path)
  if stat and stat.type ~= 'directory' then
    path = vim.fs.dirname(path)
  end
  while path do
    if vim.uv.fs_stat(path .. '/.git') or vim.uv.fs_stat(path .. '/.jj') then
      return path
    end
    path = parent_dir(path)
  end
  return nil
end

--- When both `.jj` and `.git` exist (colocated), prefer `jj` so keymaps match your primary workflow.
--- Pure Git trees (`.git` only) still return `git`.
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
  local root = M.find_root(path)
  if not root then
    return 'none'
  end
  if vim.uv.fs_stat(root .. '/.jj') then
    return 'jj'
  end
  if vim.uv.fs_stat(root .. '/.git') then
    return 'git'
  end
  return 'none'
end

return M
