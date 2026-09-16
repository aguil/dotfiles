-- Vale vocabulary: keep editable base/work fragments in sync with the live generated accept list.

local vocab_dir = vim.fs.normalize(vim.fn.expand '~/.config/vale/styles/config/vocabularies/Dotfiles')
local accept_path = vim.fs.joinpath(vocab_dir, 'accept.txt')
local base_accept_path = vim.fs.joinpath(vocab_dir, 'accept.base.txt')
local work_accept_path = vim.fs.joinpath(vocab_dir, 'accept.work.txt')

local function escape_re2(s)
  local r = s:gsub('\\', '\\\\')
  return (r:gsub('([%.%^%$%*%+%?%(%)%[%]%{%}|])', '\\%1'))
end

local function ensure_parent_dir(path) vim.fn.mkdir(vim.fs.dirname(path), 'p') end

local function read_lines(path)
  if vim.fn.filereadable(path) == 0 then return {} end
  return vim.fn.readfile(path)
end

local function append_line(path, line)
  ensure_parent_dir(path)
  for _, l in ipairs(read_lines(path)) do
    if vim.trim(l) == line then return false end
  end
  local f = io.open(path, 'a')
  if not f then
    vim.notify('[vale] cannot write ' .. path, vim.log.levels.ERROR)
    return nil
  end
  f:write(line .. '\n')
  f:close()
  return true
end

local function append_accept_line(raw, fragment_path, label)
  local term = vim.trim((raw or ''):gsub('%s+', ' '))
  if term == '' then
    vim.notify('[vale] empty term', vim.log.levels.WARN)
    return
  end
  local line = string.format('(?i)\\b%s\\b', escape_re2(term))
  local fragment_added = append_line(fragment_path, line)
  local live_added = append_line(accept_path, line)

  if fragment_added == nil or live_added == nil then return end

  if fragment_added or live_added then
    vim.notify(string.format('[vale] added %s term: %s', label, line), vim.log.levels.INFO)
  else
    vim.notify(string.format('[vale] already in %s accept list: %s', label, term), vim.log.levels.INFO)
  end

  local ok, lint = pcall(require, 'lint')
  if ok then lint.try_lint() end
end

local function edit_accept(path, label)
  ensure_parent_dir(path)
  if vim.fn.filereadable(path) == 0 then
    local f = io.open(path, 'a')
    if f then
      f:close()
    else
      vim.notify('[vale] cannot create ' .. label .. ' accept list: ' .. path, vim.log.levels.ERROR)
      return
    end
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end

return {
  {
    'folke/which-key.nvim',
    optional = true,
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      -- Use [,] not [v]: in Visual mode, v toggles charwise visual and steals the chord.
      table.insert(opts.spec, { '<leader>,', group = 'Vale terms' })
    end,
  },
  {
    'mfussenegger/nvim-lint',
    enabled = not vim.g.dot_mobile_nvim,
    keys = {
      {
        '<leader>,a',
        function() append_accept_line(vim.fn.expand '<cword>', base_accept_path, 'general') end,
        mode = 'n',
        desc = 'Vale: [,][a]dd <cword> to general accept list',
      },
      {
        '<leader>,a',
        function()
          vim.cmd 'normal! gv"zy'
          append_accept_line(vim.fn.getreg 'z', base_accept_path, 'general')
        end,
        mode = 'v',
        desc = 'Vale: [,][a]dd selection to general accept list',
      },
      {
        '<leader>,w',
        function() append_accept_line(vim.fn.expand '<cword>', work_accept_path, 'work') end,
        mode = 'n',
        desc = 'Vale: [,][w]ork-add <cword> to accept list',
      },
      {
        '<leader>,w',
        function()
          vim.cmd 'normal! gv"zy'
          append_accept_line(vim.fn.getreg 'z', work_accept_path, 'work')
        end,
        mode = 'v',
        desc = 'Vale: [,][w]ork-add selection to accept list',
      },
      {
        '<leader>,e',
        function() edit_accept(accept_path, 'live') end,
        mode = { 'n', 'v' },
        desc = 'Vale: [,][e]dit live accept list',
      },
      {
        '<leader>,b',
        function() edit_accept(base_accept_path, 'base') end,
        mode = { 'n', 'v' },
        desc = 'Vale: [,][b]ase accept list',
      },
      {
        '<leader>,W',
        function() edit_accept(work_accept_path, 'work') end,
        mode = { 'n', 'v' },
        desc = 'Vale: [,][W]ork accept list',
      },
    },
  },
}
