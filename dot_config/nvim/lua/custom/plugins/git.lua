local vcs = require 'custom.vcs'

local function notify_no_git(feature)
  vim.notify(feature .. ' needs a Git workspace (.git). jj-only repo: use :J or <leader>gj.', vim.log.levels.WARN)
end

local function open_vcs_ui()
  local kind = vcs.workspace_kind(0)
  if kind == 'git' then
    require('neogit').open()
  elseif kind == 'jj' then
    require('jj.cmd').status()
  else
    vim.notify('Not inside a Git or jj repository.', vim.log.levels.WARN)
  end
end

return {
  {
    'lewis6991/gitsigns.nvim',
    opts = function(_, opts)
      opts = opts or {}

      opts.signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      }

      opts.current_line_blame = true
      opts.current_line_blame_opts = vim.tbl_extend('force', opts.current_line_blame_opts or {}, {
        delay = 200,
      })

      local previous_on_attach = opts.on_attach

      opts.on_attach = function(bufnr)
        if vcs.workspace_kind(bufnr) ~= 'git' then
          return
        end

        if previous_on_attach then
          previous_on_attach(bufnr)
        end

        local gitsigns = require 'gitsigns'

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, 'Git: next change')

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, 'Git: previous change')

        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, 'Git: stage selected hunk')
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, 'Git: reset selected hunk')

        map('n', '<leader>hs', gitsigns.stage_hunk, 'Git: stage hunk')
        map('n', '<leader>hu', gitsigns.undo_stage_hunk, 'Git: undo stage hunk')
        map('n', '<leader>hr', gitsigns.reset_hunk, 'Git: reset hunk')
        map('n', '<leader>hS', gitsigns.stage_buffer, 'Git: stage buffer')
        map('n', '<leader>hR', gitsigns.reset_buffer, 'Git: reset buffer')
        map('n', '<leader>hp', gitsigns.preview_hunk, 'Git: preview hunk')
        map('n', '<leader>hb', gitsigns.blame_line, 'Git: blame line')
        map('n', '<leader>hd', gitsigns.diffthis, 'Git: diff vs index')
        map('n', '<leader>hD', function()
          gitsigns.diffthis '@'
        end, 'Git: diff vs last commit')

        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, 'Toggle git line blame')
        map('n', '<leader>tD', gitsigns.toggle_deleted, 'Toggle deleted lines')
      end

      return opts
    end,
  },

  {
    'evanphx/jjsigns.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    cond = function()
      return vim.fn.executable 'jj' == 1
    end,
    config = function()
      -- Only attaches when `jj root` succeeds (jj-only, colocated, or extra jj workspaces).
      -- Gitsigns above still owns git-only trees via workspace_kind in on_attach.
      local attach = require 'jjsigns.attach'
      local orig_attach_to_buffer = attach.attach_to_buffer
      if orig_attach_to_buffer then
        attach.attach_to_buffer = function(bufnr)
          local filepath = vim.api.nvim_buf_get_name(bufnr)
          if filepath:match '^jar://' then
            return
          end
          return orig_attach_to_buffer(bufnr)
        end
      end

      require('jjsigns').setup {
        signs = {
          add = { text = '+' },
          change = { text = '~' },
          delete = { text = '_' },
          topdelete = { text = '‾' },
          changedelete = { text = '~' },
        },
      }

      vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        group = vim.api.nvim_create_augroup('dot-jjsigns-skip-jar', { clear = true }),
        callback = function(args)
          local filepath = vim.api.nvim_buf_get_name(args.buf)
          if filepath:match '^jar://' then
            pcall(require('jjsigns.attach').detach_buffer, args.buf)
          end
        end,
      })
    end,
  },

  {
    'NicolasGB/jj.nvim',
    version = '*',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = { 'J', 'Jbrowse', 'Jdiff', 'Jhdiff', 'Jvdiff' },
    opts = {
      -- diffview.nvim targets Git; native diff works in jj-only trees without .git
      diff = { backend = 'native' },
    },
    config = function(_, opts)
      require('jj').setup(opts)
    end,
    keys = {
      { '<leader>gj', function() require('jj.cmd').status() end, desc = 'jj: status' },
      { '<leader>gl', function() require('jj.cmd').log {} end, desc = 'jj: log' },
    },
  },

  {
    'NeogitOrg/neogit',
    init = function()
      vim.keymap.set('n', '<leader>gg', open_vcs_ui, { desc = 'VCS: Neogit or jj status' })
    end,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'nvim-telescope/telescope.nvim',
    },
    opts = {
      kind = 'split',
      integrations = {
        diffview = true,
      },
    },
  },

  {
    'sindrets/diffview.nvim',
    keys = {
      {
        '<leader>gd',
        function()
          if vcs.workspace_kind(0) ~= 'git' then
            notify_no_git 'Diffview'
            return
          end
          vim.cmd 'DiffviewOpen'
        end,
        desc = 'Git: open diffview',
      },
      {
        '<leader>gD',
        function()
          if vcs.workspace_kind(0) ~= 'git' then
            notify_no_git 'Diffview'
            return
          end
          vim.cmd 'DiffviewClose'
        end,
        desc = 'Git: close diffview',
      },
      {
        '<leader>gh',
        function()
          if vcs.workspace_kind(0) ~= 'git' then
            notify_no_git 'Diffview file history'
            return
          end
          vim.cmd 'DiffviewFileHistory %'
        end,
        desc = 'Git: file history',
      },
      {
        '<leader>gH',
        function()
          if vcs.workspace_kind(0) ~= 'git' then
            notify_no_git 'Diffview repo history'
            return
          end
          vim.cmd 'DiffviewFileHistory'
        end,
        desc = 'Git: repo history',
      },
    },
  },

  {
    'linrongbin16/gitlinker.nvim',
    cmd = 'GitLink',
    opts = {},
    keys = {
      {
        '<leader>gy',
        function()
          if vcs.workspace_kind(0) ~= 'git' then
            notify_no_git 'GitLink'
            return
          end
          vim.cmd 'GitLink'
        end,
        mode = { 'n', 'v' },
        desc = 'Git: copy permalink',
      },
      {
        '<leader>gY',
        function()
          if vcs.workspace_kind(0) ~= 'git' then
            notify_no_git 'GitLink'
            return
          end
          vim.cmd 'GitLink!'
        end,
        mode = { 'n', 'v' },
        desc = 'Git: open permalink',
      },
    },
  },

  {
    'nvim-telescope/telescope.nvim',
    keys = {
      {
        '<leader>gs',
        function()
          local kind = vcs.workspace_kind(0)
          if kind == 'git' then
            require('telescope.builtin').git_status()
          elseif kind == 'jj' then
            require('jj.cmd').status()
          else
            vim.notify('Not inside a Git or jj repository.', vim.log.levels.WARN)
          end
        end,
        desc = 'VCS: status (Git picker / jj)',
      },
      {
        '<leader>gc',
        function()
          local kind = vcs.workspace_kind(0)
          if kind == 'git' then
            require('telescope.builtin').git_commits()
          elseif kind == 'jj' then
            require('jj.cmd').log {}
          else
            vim.notify('Not inside a Git or jj repository.', vim.log.levels.WARN)
          end
        end,
        desc = 'VCS: commits / jj log',
      },
      {
        '<leader>gB',
        function()
          if vcs.workspace_kind(0) ~= 'git' then
            notify_no_git 'Telescope git branches'
            return
          end
          require('telescope.builtin').git_branches()
        end,
        desc = 'Git: branch picker',
      },
    },
  },
}
