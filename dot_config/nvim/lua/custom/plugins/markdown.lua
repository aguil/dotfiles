-- Markdown prose: render/preview support, non-standard extensions, and 80-column wrapping.

local prose_extensions = {
  mdc = true,
  mdx = true,
}

local function is_wsl()
  local uname = (vim.uv or vim.loop).os_uname()
  return uname.release:lower():find('microsoft', 1, true) ~= nil
end

local function is_macos() return (vim.uv or vim.loop).os_uname().sysname == 'Darwin' end

local function kitty_graphics_terminal()
  local term = (vim.env.TERM or ''):lower()
  local term_program = (vim.env.TERM_PROGRAM or ''):lower()

  return vim.env.KITTY_WINDOW_ID ~= nil
    or vim.env.WEZTERM_PANE ~= nil
    or term:find('kitty', 1, true) ~= nil
    or term:find('ghostty', 1, true) ~= nil
    or term:find('wezterm', 1, true) ~= nil
    or term_program:find('ghostty', 1, true) ~= nil
    or term_program:find('wezterm', 1, true) ~= nil
    or (
      vim.env.TMUX ~= nil
      and vim.fn.executable 'tmux' == 1
      and vim.iter(vim.fn.systemlist { 'tmux', 'display-message', '-p', '#{client_termname}' }):any(function(value)
        local client_term = value:lower()
        return client_term:find('ghostty', 1, true) ~= nil or client_term:find('kitty', 1, true) ~= nil or client_term:find('wezterm', 1, true) ~= nil
      end)
    )
end

local function sixel_graphics_terminal() return is_wsl() and vim.env.WT_SESSION ~= nil end

---@return 'kitty'|'sixel'|nil
local function graphics_backend()
  if vim.env.NVIM_IMAGE_BACKEND == 'kitty' or vim.env.NVIM_IMAGE_BACKEND == 'sixel' then return vim.env.NVIM_IMAGE_BACKEND end
  if sixel_graphics_terminal() then return 'sixel' end
  if kitty_graphics_terminal() then return 'kitty' end
  if is_macos() and vim.env.TMUX ~= nil then return 'kitty' end
  return nil
end

local function terminal_graphics_supported() return vim.env.NVIM_IMAGE_SUPPORT == '1' or graphics_backend() ~= nil end

local function image_nvim_opts()
  local backend = graphics_backend()
  if backend == nil then backend = is_wsl() and 'sixel' or 'kitty' end
  -- Sixel popup mode opens a float (WinNew) that races image.nvim's global
  -- schedule_all_window_render clear/repaint cycle: image flashes, then :mode
  -- wipes pixels. Inline at cursor avoids the float and cleans up on leave.
  local cursor_image_mode = backend == 'sixel' and 'inline' or 'popup'

  return {
    backend = backend,
    processor = 'magick_cli',
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = true,
        only_render_image_at_cursor_mode = cursor_image_mode,
        filetypes = { 'markdown' },
      },
      asciidoc = { enabled = false },
      neorg = { enabled = false },
      rst = { enabled = false },
      typst = { enabled = false },
      html = { enabled = false },
      css = { enabled = false },
    },
    max_height_window_percentage = 45,
    -- Sixel uses async :mode clears; tmux focus toggles race with repaint.
    tmux_show_only_in_active_window = vim.env.TMUX ~= nil and backend ~= 'sixel',
    hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif' },
  }
end

local function configure_markdown_preview_browser()
  if not is_wsl() then return end

  vim.g.mkdp_echo_preview_url = 1
  vim.g.mkdp_browserfunc = 'OpenMarkdownPreview'

  vim.cmd [[
    function! OpenMarkdownPreview(url) abort
      if executable('wslview')
        call jobstart(['wslview', a:url], {'detach': v:true})
      elseif executable('cmd.exe')
        call jobstart(['cmd.exe', '/c', 'start', '""', a:url], {'detach': v:true})
      else
        echo a:url
      endif
    endfunction
  ]]
end

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
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },
    init = function() require('custom.markdown_nav').setup() end,
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      anti_conceal = {
        enabled = false,
      },
      completions = {
        lsp = { enabled = true },
      },
      file_types = { 'markdown' },
    },
  },

  {
    'iamcco/markdown-preview.nvim',
    enabled = not vim.g.dot_mobile_nvim,
    cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
    ft = { 'markdown' },
    build = 'cd app && npm install',
    init = function()
      vim.g.mkdp_filetypes = { 'markdown' }
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_refresh_slow = 0
      configure_markdown_preview_browser()
      vim.g.mkdp_preview_options = {
        mkit = {},
        katex = {},
        uml = {},
        maid = {},
        disable_sync_scroll = 0,
        sync_scroll_type = 'middle',
        hide_yaml_meta = 1,
        sequence_diagrams = {},
        flowchart_diagrams = {},
        content_editable = false,
        disable_filename = 0,
        toc = {},
      }
    end,
    keys = {
      { '<leader>mp', '<cmd>MarkdownPreviewToggle<cr>', desc = 'Markdown preview' },
    },
  },

  {
    '3rd/image.nvim',
    cond = function() return not vim.g.dot_mobile_nvim and terminal_graphics_supported() end,
    event = 'VeryLazy',
    build = false,
    opts = image_nvim_opts,
  },

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
