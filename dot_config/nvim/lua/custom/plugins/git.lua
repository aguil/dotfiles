return {
  {
    'lewis6991/gitsigns.nvim',
    opts = function(_, opts)
      opts = opts or {}

      opts.current_line_blame = true
      opts.current_line_blame_opts = vim.tbl_extend('force', opts.current_line_blame_opts or {}, {
        delay = 200,
      })

      local previous_on_attach = opts.on_attach

      opts.on_attach = function(bufnr)
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
    'NeogitOrg/neogit',
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
    keys = {
      { '<leader>gg', function() require('neogit').open() end, desc = 'Git: open Neogit' },
    },
  },

  {
    'sindrets/diffview.nvim',
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<CR>', desc = 'Git: open diffview' },
      { '<leader>gD', '<cmd>DiffviewClose<CR>', desc = 'Git: close diffview' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<CR>', desc = 'Git: file history' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<CR>', desc = 'Git: repo history' },
    },
  },

  {
    'linrongbin16/gitlinker.nvim',
    cmd = 'GitLink',
    opts = {},
    keys = {
      { '<leader>gy', '<cmd>GitLink<CR>', mode = { 'n', 'v' }, desc = 'Git: copy permalink' },
      { '<leader>gY', '<cmd>GitLink!<CR>', mode = { 'n', 'v' }, desc = 'Git: open permalink' },
    },
  },

  {
    'nvim-telescope/telescope.nvim',
    keys = {
      {
        '<leader>gs',
        function()
          require('telescope.builtin').git_status()
        end,
        desc = 'Git: status picker',
      },
      {
        '<leader>gc',
        function()
          require('telescope.builtin').git_commits()
        end,
        desc = 'Git: commit picker',
      },
      {
        '<leader>gB',
        function()
          require('telescope.builtin').git_branches()
        end,
        desc = 'Git: branch picker',
      },
    },
  },
}
