-- Vale vocabulary: append to ~/.config/vale/styles/.../accept.txt (sync back into chezmoi when needed).

local accept_path = vim.fs.normalize(vim.fn.expand('~/.config/vale/styles/config/vocabularies/Dotfiles/accept.txt'))

local function escape_re2(s)
  local r = s:gsub('\\', '\\\\')
  return (r:gsub('([%.%^%$%*%+%?%(%)%[%]%{%}|])', '\\%1'))
end

local function append_accept_line(raw)
  local term = vim.trim((raw or ''):gsub('%s+', ' '))
  if term == '' then
    vim.notify('[vale] empty term', vim.log.levels.WARN)
    return
  end
  if vim.fn.filereadable(accept_path) == 0 then
    vim.notify('[vale] missing accept list (chezmoi apply?): ' .. accept_path, vim.log.levels.ERROR)
    return
  end
  local line = string.format('(?i)\\b%s\\b', escape_re2(term))
  for _, l in ipairs(vim.fn.readfile(accept_path)) do
    if vim.trim(l) == line then
      vim.notify('[vale] already in accept list: ' .. term, vim.log.levels.INFO)
      return
    end
  end
  local f = io.open(accept_path, 'a')
  if not f then
    vim.notify('[vale] cannot write ' .. accept_path, vim.log.levels.ERROR)
    return
  end
  f:write(line .. '\n')
  f:close()
  vim.notify('[vale] added: ' .. line, vim.log.levels.INFO)
  local ok, lint = pcall(require, 'lint')
  if ok then
    lint.try_lint()
  end
end

return {
  {
    'folke/which-key.nvim',
    optional = true,
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>v', group = '[V]ale' })
    end,
  },
  {
    'mfussenegger/nvim-lint',
    keys = {
      {
        '<leader>vA',
        function()
          append_accept_line(vim.fn.expand('<cword>'))
        end,
        mode = 'n',
        desc = '[V]ale [A]dd <cword> to accept list',
      },
      {
        '<leader>vA',
        function()
          vim.cmd 'normal! gv"zy'
          append_accept_line(vim.fn.getreg 'z')
        end,
        mode = 'v',
        desc = '[V]ale [A]dd selection to accept list',
      },
      {
        '<leader>ve',
        function()
          if vim.fn.filereadable(accept_path) == 0 then
            vim.notify('[vale] missing accept list (chezmoi apply?): ' .. accept_path, vim.log.levels.ERROR)
            return
          end
          vim.cmd('edit ' .. vim.fn.fnameescape(accept_path))
        end,
        desc = '[V]ale [E]dit accept list',
      },
    },
  },
}
