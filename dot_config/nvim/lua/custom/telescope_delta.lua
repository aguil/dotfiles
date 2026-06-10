--- Delta-backed diff previews for Telescope git pickers.
local M = {}

local vcs = require 'custom.vcs'

local delta_args = { 'delta', '--paging=never', '--default-language', 'bash' }
local delta_location_args = {
  'delta',
  '--paging=never',
  '--default-language',
  'bash',
  '--line-numbers',
}

local function delta_args_for(profile)
  if profile == 'location' then
    return delta_location_args
  end
  return delta_args
end

local function strip_ansi(text)
  return text:gsub('\27%[[0-9;]*[A-Za-z]', '')
end

local function delta_line_number(plain)
  local old_num, new_num = plain:match('⋮%s+(%d+)%s+(%d+)%s*│')
  if new_num then
    return tonumber(new_num)
  end

  local single = plain:match('⋮%s+(%d+)%s*│')
  if single then
    return tonumber(single)
  end

  return nil
end

local function find_reference_line(lines, lnum)
  for i, line in ipairs(lines) do
    if delta_line_number(strip_ansi(line)) == lnum then
      return i
    end
  end
  return nil
end

local location_scroll_epoch = 0
local last_terminal_scroll = {}
local diff_covers_line = {}

local function bump_scroll_epoch()
  location_scroll_epoch = location_scroll_epoch + 1
  return location_scroll_epoch
end

local function clear_terminal_scroll_state()
  last_terminal_scroll = {}
end

local function clear_location_preview_state()
  clear_terminal_scroll_state()
  diff_covers_line = {}
end

local function line_preview_key(path, lnum)
  return (path or '') .. ':' .. tostring(lnum or '') .. ':' .. vcs.base_mode
end

local function reset_terminal_preview_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= 'terminal' then
    return
  end

  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].buftype = ''
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.bo[bufnr].modified = false
end

local function diff_buffer_has_line(bufnr, lnum)
  if not lnum or lnum <= 0 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  return find_reference_line(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), lnum) ~= nil
end

local function preview_win_execute(winid, command)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return
  end
  pcall(vim.fn.win_execute, winid, command)
end

local function scroll_terminal_to_line(bufnr, winid, lnum, opts)
  opts = opts or {}
  if not lnum or lnum <= 0 or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  local epoch = opts.epoch
  local scroll_key = bufnr .. ':' .. lnum
  if last_terminal_scroll[scroll_key] and not opts.force then
    return
  end

  local function preview_stale()
    return opts.preview_key and opts.get_preview_key and opts.get_preview_key() ~= opts.preview_key
  end

  local function step(attempt)
    if preview_stale() then
      return
    end
    if epoch and epoch ~= location_scroll_epoch then
      return
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local target = find_reference_line(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), lnum)
    if not target then
      if attempt == 0 then
        vim.defer_fn(function()
          step(1)
        end, 100)
        return
      end
      if opts.on_missing_line then
        opts.on_missing_line()
      end
      return
    end

    preview_win_execute(winid, 'normal! ' .. target .. 'Gzz')
    last_terminal_scroll[scroll_key] = true
    if opts.path then
      diff_covers_line[line_preview_key(opts.path, lnum)] = true
    end
  end

  if opts.immediate then
    vim.schedule(function()
      step(0)
    end)
  else
    vim.defer_fn(function()
      step(0)
    end, 30)
  end
end

--- @param opts? { profile?: 'location', lnum?: integer, winid?: integer }
--- Render `diff_cmd` piped through delta in a preview terminal buffer.
function M.termopen_diff(bufnr, cwd, diff_cmd, opts)
  opts = opts or {}

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Reused preview buffers stay as terminals; delta output is already rendered.
  if vim.bo[bufnr].buftype == 'terminal' then
    if opts.lnum and opts.winid then
      if not diff_buffer_has_line(bufnr, opts.lnum) then
        if opts.on_missing_line then
          opts.on_missing_line()
        end
        return
      end
      scroll_terminal_to_line(bufnr, opts.winid, opts.lnum, opts)
    end
    return
  end

  local epoch = bump_scroll_epoch()
  clear_terminal_scroll_state()

  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].buftype = ''

  local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
  if vim.api.nvim_buf_line_count(bufnr) > 1 or first_line ~= '' then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  end

  -- termopen/jobstart({term=true}) requires an unmodified buffer.
  vim.bo[bufnr].modified = false

  local delta = delta_args_for(opts.profile)
  local command = M.shell_join(diff_cmd) .. ' | ' .. M.shell_join(delta)
  vim.api.nvim_buf_call(bufnr, function()
    vim.fn.jobstart({ 'bash', '-lc', command }, {
      cwd = cwd,
      term = true,
      env = vim.fn.environ(),
      on_exit = function()
        vim.schedule(function()
          if opts.lnum and opts.winid then
            scroll_terminal_to_line(bufnr, opts.winid, opts.lnum, vim.tbl_extend('force', opts, { epoch = epoch }))
          end
        end)
      end,
    })
  end)
end

function M.available()
  return vim.fn.executable 'delta' == 1
end

function M.shell_join(cmd)
  return table.concat(vim.tbl_map(vim.fn.shellescape, cmd), ' ')
end

--- @param opts? { context?: integer }
function M.file_diff_spec(filepath, cwd, opts)
  return vcs.file_diff_spec(filepath, { cwd = cwd, context = opts and opts.context })
end

function M.file_has_diff(filepath, cwd)
  return vcs.file_has_diff(filepath, { cwd = cwd })
end

local function vimgrep_fallback_preview(self, entry, opts, cwd, jump_to_line)
  local api = vim.api
  local from_entry = require 'telescope.from_entry'
  local conf = require('telescope.config').values

  local has_buftype = entry.bufnr and api.nvim_buf_is_valid(entry.bufnr) and vim.bo[entry.bufnr].buftype ~= ''
    or false
  local path
  if not has_buftype then
    path = from_entry.path(entry, true, false)
    if path == nil or path == '' then
      return
    end
  end

  if entry.bufnr and (path == '[No Name]' or has_buftype) then
    local lines = api.nvim_buf_get_lines(entry.bufnr, 0, -1, false)
    api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    vim.schedule(function()
      jump_to_line(self, self.state.bufnr, entry)
    end)
    return
  end

  conf.buffer_previewer_maker(path, self.state.bufnr, {
    bufname = self.state.bufname,
    winid = self.state.winid,
    preview = opts.preview,
    callback = function(bufnr)
      jump_to_line(self, bufnr, entry)
    end,
    file_encoding = opts.file_encoding,
  })
end

local function make_location_previewer(title, opts)
  local previewers = require 'telescope.previewers'
  local from_entry = require 'telescope.from_entry'
  local Path = require 'plenary.path'
  local api = vim.api
  local hl = vim.hl
  local ns_previewer = api.nvim_create_namespace 'telescope.previewers'

  opts = opts or {}
  local cwd = opts.cwd or vim.uv.cwd()

  local function entry_path(entry, validate)
    return from_entry.path(entry, validate, false)
  end

  local function entry_lnum(entry)
    if entry.lnum and entry.lnum > 0 then
      return entry.lnum
    end
    local value = entry.value
    if type(value) == 'table' and value.lnum and value.lnum > 0 then
      return value.lnum
    end
    return nil
  end

  local function entry_col(entry)
    if entry.col and entry.col > 0 then
      return entry.col
    end
    local value = entry.value
    if type(value) == 'table' and value.col and value.col > 0 then
      return value.col
    end
    return nil
  end

  local function location_suffix(entry)
    local lnum = entry_lnum(entry)
    if not lnum then
      return ''
    end
    local col = entry_col(entry)
    if col then
      return ':' .. lnum .. ':' .. col
    end
    return ':' .. lnum
  end

  local function preview_label(entry)
    local path = entry_path(entry, false)
    if not path or path == '' then
      return title
    end
    path = Path:new(path):normalize(cwd)
    local suffix = location_suffix(entry)
    if M.available() and M.file_has_diff(path, cwd) then
      local spec = M.file_diff_spec(path, cwd)
      if spec then
        return 'Diff (' .. spec.label .. '): ' .. path .. suffix
      end
    end
    return path .. suffix
  end

  local jump_to_line = function(self, bufnr, entry)
    pcall(api.nvim_buf_clear_namespace, bufnr, ns_previewer, 0, -1)

    if entry.lnum and entry.lnum > 0 then
      local lnum, lnend = entry.lnum - 1, (entry.lnend or entry.lnum) - 1
      local col, colend = 0, -1
      if entry.col and entry.colend then
        col, colend = entry.col - 1, entry.colend - 1
      end

      for i = lnum, lnend do
        pcall(
          hl.range,
          bufnr,
          ns_previewer,
          'TelescopePreviewLine',
          { i, i == lnum and col or 0 },
          { i, i == lnend and colend or -1 }
        )
      end

      local middle_ln = math.floor(lnum + (lnend - lnum) / 2)
      pcall(api.nvim_win_set_cursor, self.state.winid, { middle_ln + 1, 0 })
      preview_win_execute(self.state.winid, 'normal! zz')
    end
  end

  return previewers.new_buffer_previewer {
    title = title,
    dyn_title = function(_, entry)
      return preview_label(entry)
    end,
    teardown = function()
      bump_scroll_epoch()
      clear_location_preview_state()
      vcs.clear_file_diff_cache()
    end,
    get_buffer_by_name = function(_, entry)
      local path = entry_path(entry, false)
      if not path or path == '' then
        return nil
      end
      local lnum = entry_lnum(entry)
      if lnum and diff_covers_line[line_preview_key(path, lnum)] == false then
        return path
      end
      if M.available() and M.file_has_diff(path, cwd) then
        return path .. '::diff::' .. vcs.base_mode
      end
      return path
    end,
    define_preview = function(self, entry, status)
      local preview_winid = status and status.layout and status.layout.preview and status.layout.preview.winid
      if preview_winid and vim.api.nvim_win_is_valid(preview_winid) then
        self.state.winid = preview_winid
      end

      local path = entry_path(entry, true)
      local lnum = entry_lnum(entry)
      local col = entry_col(entry)
      local preview_key = table.concat({
        path or '',
        tostring(lnum or ''),
        tostring(col or ''),
        vcs.base_mode,
      }, ':')

      if self._delta_preview_key == preview_key then
        return
      end
      self._delta_preview_key = preview_key
      clear_terminal_scroll_state()

      local function show_file_at_line()
        if path and lnum then
          diff_covers_line[line_preview_key(path, lnum)] = false
        end
        reset_terminal_preview_buffer(self.state.bufnr)
        vimgrep_fallback_preview(self, entry, opts, cwd, jump_to_line)
      end

      if path and M.available() and lnum and diff_covers_line[line_preview_key(path, lnum)] ~= false then
        local preview_height = self.state.winid and vim.api.nvim_win_get_height(self.state.winid) or 20
        local context = math.max(6, math.floor(preview_height / 3))
        local spec = M.file_diff_spec(path, cwd, { context = context })
        if spec then
          local scroll_opts = {
            profile = 'location',
            lnum = lnum,
            winid = self.state.winid,
            path = path,
            immediate = true,
            force = true,
            preview_key = preview_key,
            get_preview_key = function()
              return self._delta_preview_key
            end,
            on_missing_line = show_file_at_line,
          }
          M.termopen_diff(self.state.bufnr, spec.cwd or cwd, spec.cmd, scroll_opts)
          return
        end
      end

      show_file_at_line()
    end,
  }
end

--- Quickfix/LSP previewer: delta git diff when the file has local changes, else file-at-line.
function M.qflist_previewer(opts)
  return make_location_previewer('Location Preview', opts)
end

--- Grep previewer: same git-diff-first behavior as qflist (used by live_grep, etc.).
function M.grep_previewer(opts)
  return make_location_previewer('Grep Preview', opts)
end

local function git_file_diff_previewer(opts)
  local previewers = require 'telescope.previewers'
  local conf = require('telescope.config').values
  local from_entry = require 'telescope.from_entry'
  local git_command = require('telescope.utils').__git_command

  return previewers.new_buffer_previewer {
    title = 'Git File Diff Preview',
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,
    define_preview = function(self, entry)
      if entry.status and (entry.status == '??' or entry.status == 'A ') then
        local p = from_entry.path(entry, true, false)
        if p == nil or p == '' then
          return
        end
        conf.buffer_previewer_maker(p, self.state.bufnr, {
          bufname = self.state.bufname,
          winid = self.state.winid,
          preview = opts.preview,
          file_encoding = opts.file_encoding,
        })
        return
      end

      local diff_cmd = git_command({ '--no-pager', 'diff', 'HEAD', '--', entry.value }, opts)
      M.termopen_diff(self.state.bufnr, opts.cwd, diff_cmd)
    end,
  }
end

local function git_commit_diff_previewer(title, build_args, opts)
  local previewers = require 'telescope.previewers'
  local git_command = require('telescope.utils').__git_command

  return previewers.new_buffer_previewer {
    title = title,
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,
    define_preview = function(self, entry)
      local diff_cmd = git_command(build_args(entry, opts), opts)
      M.termopen_diff(self.state.bufnr, opts.cwd, diff_cmd)
    end,
  }
end

local function git_commit_diff_to_parent_previewer(opts)
  return git_commit_diff_previewer('Git Diff to Parent Preview', function(entry, picker_opts)
    local args = { '--no-pager', 'diff', entry.value .. '^!' }
    if picker_opts.current_file then
      table.insert(args, '--')
      table.insert(args, picker_opts.current_file)
    end
    return args
  end, opts)
end

local function git_commit_diff_to_head_previewer(opts)
  return git_commit_diff_previewer('Git Diff to Head Preview', function(entry, picker_opts)
    local args = { '--no-pager', 'diff', '--cached', entry.value }
    if picker_opts.current_file then
      table.insert(args, '--')
      table.insert(args, picker_opts.current_file)
    end
    return args
  end, opts)
end

local function git_commit_diff_as_was_previewer(opts)
  local Path = require 'plenary.path'
  local previewers = require 'telescope.previewers'
  local git_command = require('telescope.utils').__git_command

  return previewers.new_buffer_previewer {
    title = 'Git Show Preview',
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,
    define_preview = function(self, entry)
      local cf = opts.current_file and Path:new(opts.current_file):make_relative(opts.cwd)
      local value = cf and (entry.value .. ':' .. cf) or entry.value
      local diff_cmd = git_command({ '--no-pager', 'show', value }, opts)
      M.termopen_diff(self.state.bufnr, opts.cwd, diff_cmd)
    end,
  }
end

local function git_stash_diff_previewer(opts)
  local previewers = require 'telescope.previewers'
  local git_command = require('telescope.utils').__git_command

  return previewers.new_buffer_previewer {
    title = 'Git Stash Preview',
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,
    define_preview = function(self, entry)
      local diff_cmd = git_command({ '--no-pager', 'stash', 'show', '-p', entry.value }, opts)
      M.termopen_diff(self.state.bufnr, opts.cwd, diff_cmd)
    end,
  }
end

local function wrap_previewer_new(name, factory)
  local previewers = require 'telescope.previewers'
  local defaulter = previewers[name]
  if not defaulter or type(defaulter.new) ~= 'function' then
    return
  end

  local orig_new = defaulter.new
  defaulter.new = function(opts)
    if M.available() then
      return factory(opts)
    end
    return orig_new(opts)
  end
end

--- Replace Telescope git diff previewers with delta term previews when available.
function M.apply_git_previewers()
  if M._applied or not M.available() then
    return
  end
  M._applied = true

  wrap_previewer_new('git_file_diff', git_file_diff_previewer)
  wrap_previewer_new('git_commit_diff_to_parent', git_commit_diff_to_parent_previewer)
  wrap_previewer_new('git_commit_diff_to_head', git_commit_diff_to_head_previewer)
  wrap_previewer_new('git_commit_diff_as_was', git_commit_diff_as_was_previewer)
  wrap_previewer_new('git_stash_diff', git_stash_diff_previewer)
end

return M
