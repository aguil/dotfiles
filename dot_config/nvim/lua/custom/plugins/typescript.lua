return {
  {
    'pmizio/typescript-tools.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'neovim/nvim-lspconfig',
    },
    ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    config = function()
      require('typescript-tools').setup {
        settings = {
          tsserver_file_preferences = {
            includeInlayParameterNameHints = 'all',
            includeInlayParameterNameHintsWhenArgumentMatchesName = true,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayVariableTypeHints = true,
            includeInlayPropertyDeclarationTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
            includeInlayEnumMemberValueHints = true,
          },
        },
        on_attach = function(client, bufnr)
          client.server_capabilities.documentFormattingProvider = false

          local map = function(lhs, rhs, desc)
            vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc })
          end

          map('<leader>co', '<cmd>TSToolsOrganizeImports<CR>', 'TS: organize imports')
          map('<leader>cR', '<cmd>TSToolsRenameFile<CR>', 'TS: rename file and imports')
          map('<leader>cu', '<cmd>TSToolsRemoveUnusedImports<CR>', 'TS: remove unused imports')
          map('<leader>cM', '<cmd>TSToolsAddMissingImports<CR>', 'TS: add missing imports')
          map('<leader>cF', '<cmd>TSToolsFixAll<CR>', 'TS: fix all diagnostics')
          map('gD', '<cmd>TSToolsGoToSourceDefinition<CR>', 'TS: go to source definition')
        end,
      }
    end,
  },

  {
    'stevearc/conform.nvim',
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.javascript = { 'prettierd', 'prettier', stop_after_first = true }
      opts.formatters_by_ft.javascriptreact = { 'prettierd', 'prettier', stop_after_first = true }
      opts.formatters_by_ft.typescript = { 'prettierd', 'prettier', stop_after_first = true }
      opts.formatters_by_ft.typescriptreact = { 'prettierd', 'prettier', stop_after_first = true }

      local previous = opts.format_on_save
      opts.format_on_save = function(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == 'javascript' or ft == 'javascriptreact' or ft == 'typescript' or ft == 'typescriptreact' then
          return {
            timeout_ms = 500,
            lsp_format = 'never',
          }
        end

        if type(previous) == 'function' then
          return previous(bufnr)
        end

        return previous
      end
    end,
  },

  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = lint.linters_by_ft or {}
      lint.linters_by_ft.javascript = { 'eslint_d' }
      lint.linters_by_ft.javascriptreact = { 'eslint_d' }
      lint.linters_by_ft.typescript = { 'eslint_d' }
      lint.linters_by_ft.typescriptreact = { 'eslint_d' }

      -- nvim-lint's default linters_by_ft still lists vale for markdown/text/rst.
      -- This augroup would otherwise call try_lint() on every buffer and hit ENOENT
      -- when vale is not installed.
      local eslint_ft = {
        javascript = true,
        javascriptreact = true,
        typescript = true,
        typescriptreact = true,
      }

      local lint_augroup = vim.api.nvim_create_augroup('lint-typescript', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          if not vim.bo.modifiable or not eslint_ft[vim.bo.filetype] then
            return
          end
          lint.try_lint()
        end,
      })
    end,
  },

  {
    'folke/trouble.nvim',
    cmd = 'Trouble',
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>', desc = 'Diagnostics: toggle trouble' },
      { '<leader>xw', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', desc = 'Diagnostics: trouble (buffer)' },
      { '<leader>xs', '<cmd>Trouble symbols toggle focus=false<CR>', desc = 'Symbols: trouble' },
    },
    opts = {},
  },

  {
    'dmmulroy/ts-error-translator.nvim',
    ft = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    opts = {},
  },

  {
    'windwp/nvim-ts-autotag',
    ft = { 'javascriptreact', 'typescriptreact', 'html' },
    opts = {},
  },
}
