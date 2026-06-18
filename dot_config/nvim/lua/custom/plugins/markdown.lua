-- Markdown prose: non-standard extensions (.mdc/.mdx) and 80-column wrapping.

local prose_extensions = {
  mdc = true,
  mdx = true,
}

---@param filename string
---@return string
local function markdown_filename(filename)
  local ext = vim.fn.fnamemodify(filename, ':e'):lower()
  if prose_extensions[ext] then return vim.fn.fnamemodify(filename, ':r') .. '.md' end
  return filename
end

local function markdown_prettier_args(_, ctx)
  return {
    '--parser',
    'markdown',
    '--config-precedence',
    'cli-override',
    '--prose-wrap',
    'always',
    '--print-width',
    '80',
    '--stdin-filepath',
    markdown_filename(ctx.filename),
  }
end

return {
  {
    'stevearc/conform.nvim',
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      -- prettierd picks proseWrap from a discovered .prettierrc; outside a repo
      -- tree it leaves long lines untouched. Use prettier with explicit wrap args.
      opts.formatters.markdown_prettier = {
        command = require('conform.util').from_node_modules 'prettier',
        args = markdown_prettier_args,
        range_args = function(_, ctx)
          local util = require 'conform.util'
          local start_offset, end_offset = util.get_offsets_from_range(ctx.buf, ctx.range)
          return vim.list_extend(markdown_prettier_args(nil, ctx), {
            '--range-start=' .. start_offset,
            '--range-end=' .. end_offset,
          })
        end,
        cwd = require('conform.formatters.prettierd').cwd,
      }

      opts.formatters_by_ft.markdown = { 'markdown_prettier' }

      -- Keep prettierd path remapping for any buffer that still uses it.
      opts.formatters.prettierd = vim.tbl_deep_extend('force', opts.formatters.prettierd or {}, {
        inherit = true,
        args = function(_, ctx) return { markdown_filename(ctx.filename) } end,
        range_args = function(_, ctx)
          local util = require 'conform.util'
          local start_offset, end_offset = util.get_offsets_from_range(ctx.buf, ctx.range)
          return {
            markdown_filename(ctx.filename),
            '--range-start=' .. start_offset,
            '--range-end=' .. end_offset,
          }
        end,
      })

      opts.formatters.prettier = vim.tbl_deep_extend('force', opts.formatters.prettier or {}, {
        inherit = true,
        options = {
          ext_parsers = {
            mdc = 'markdown',
            mdx = 'markdown',
          },
        },
      })

      local previous = opts.format_on_save
      opts.format_on_save = function(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == 'markdown' then return {
          timeout_ms = 3000,
          lsp_format = 'never',
        } end

        if type(previous) == 'function' then return previous(bufnr) end

        return previous
      end
    end,
  },
}
