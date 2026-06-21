local function reload_markdown_specs()
  package.loaded['custom.plugins.markdown'] = nil
  return require 'custom.plugins.markdown'
end

local function spec_by_plugin(specs, plugin)
  for _, spec in ipairs(specs) do
    if spec[1] == plugin then return spec end
  end
end

local function with_os_release(release, fn)
  local original_os_uname = vim.uv.os_uname
  vim.uv.os_uname = function() return { release = release } end

  local ok, err = pcall(fn)
  vim.uv.os_uname = original_os_uname
  if not ok then error(err, 0) end
end

local function with_env(vars, fn)
  local previous = {}
  for key in pairs(vars) do
    previous[key] = vim.env[key]
    vim.env[key] = vars[key]
  end

  local ok, err = pcall(fn)
  for key, value in pairs(previous) do
    vim.env[key] = value
  end
  if not ok then error(err, 0) end
end

local function with_markdown_buffer(lines, row, col, fn)
  local previous = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].filetype = 'markdown'
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { row, col })

  local ok, err = pcall(fn, bufnr)
  vim.api.nvim_set_current_buf(previous)
  pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  if not ok then error(err, 0) end
end

local function with_temp_markdown(lines, fn)
  local path = vim.fn.tempname() .. '.md'
  vim.fn.writefile(lines, path)

  local ok, err = pcall(fn, path)
  os.remove(path)
  if not ok then error(err, 0) end
end

local function with_package_stub(name, stub, fn)
  local previous = package.loaded[name]
  package.loaded[name] = stub

  local ok, err = pcall(fn)
  package.loaded[name] = previous
  if not ok then error(err, 0) end
end

describe('custom.plugins.markdown', function()
  before_each(function()
    vim.g.mkdp_filetypes = nil
    vim.g.mkdp_auto_start = nil
    vim.g.mkdp_auto_close = nil
    vim.g.mkdp_refresh_slow = nil
    vim.g.mkdp_browserfunc = nil
    vim.g.mkdp_echo_preview_url = nil
    pcall(vim.cmd, 'delfunction OpenMarkdownPreview')
  end)

  it('declares render and browser preview plugins for markdown buffers', function()
    local specs = reload_markdown_specs()

    local render = spec_by_plugin(specs, 'MeanderingProgrammer/render-markdown.nvim')
    local preview = spec_by_plugin(specs, 'iamcco/markdown-preview.nvim')

    asserts.truthy(render)
    asserts.same({ 'markdown' }, render.ft)
    asserts.equals(false, render.opts.anti_conceal.enabled)
    asserts.equals(true, render.opts.completions.lsp.enabled)

    asserts.truthy(preview)
    asserts.same({ 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' }, preview.cmd)
    asserts.same({ 'markdown' }, preview.ft)
    asserts.equals('cd app && npm install', preview.build)
    asserts.equals('<leader>mp', preview.keys[1][1])
  end)

  it('installs markdown-local preview and outline mappings with render-markdown init', function()
    local render = spec_by_plugin(reload_markdown_specs(), 'MeanderingProgrammer/render-markdown.nvim')
    render.init()

    with_markdown_buffer({ '# Notes' }, 1, 0, function(bufnr)
      vim.api.nvim_exec_autocmds('FileType', { buffer = bufnr, modeline = false })
      local peek_link = vim.fn.maparg('<leader>gp', 'n', false, true)
      local outline = vim.fn.maparg('gO', 'n', false, true)

      asserts.equals('Markdown: peek linked file', peek_link.desc)
      asserts.equals(1, peek_link.buffer)
      asserts.equals('Markdown: outline headings and links', outline.desc)
      asserts.equals(1, outline.buffer)
    end)
  end)

  it('extracts markdown link destinations under the cursor', function()
    package.loaded['custom.markdown_nav'] = nil
    local nav = require 'custom.markdown_nav'

    with_markdown_buffer(
      { 'Read the [guide](docs/Guide%20Book.md#Install "title").' },
      1,
      12,
      function() asserts.equals('docs/Guide Book.md#Install', nav.target_under_cursor()) end
    )
  end)

  it('extracts reference-style markdown links under the cursor', function()
    package.loaded['custom.markdown_nav'] = nil
    local nav = require 'custom.markdown_nav'

    with_markdown_buffer({
      'Read [the docs][Docs] before editing.',
      '',
      '[docs]: docs/reference.md "Reference docs"',
    }, 1, 8, function() asserts.equals('docs/reference.md', nav.target_under_cursor()) end)
  end)

  it('does not treat footnotes as reference-style file links', function()
    package.loaded['custom.markdown_nav'] = nil
    local nav = require 'custom.markdown_nav'

    with_markdown_buffer({
      'Read this note[^1] before editing.',
      '',
      '[^1]: Footnote body, not a path.',
    }, 1, 15, function() asserts.falsy(nav.target_under_cursor()) end)
  end)

  it('extracts wiki note links under the cursor', function()
    package.loaded['custom.markdown_nav'] = nil
    local nav = require 'custom.markdown_nav'

    with_markdown_buffer({ 'Open [[Project Notes#Today|today]].' }, 1, 8, function() asserts.equals('Project Notes#Today', nav.target_under_cursor()) end)
  end)

  it('opens linked markdown files in a floating preview buffer', function()
    package.loaded['custom.markdown_nav'] = nil
    local nav = require 'custom.markdown_nav'

    with_temp_markdown({ '# Linked Note', '', 'Preview body.' }, function(path)
      with_markdown_buffer({ string.format('Read [linked](%s).', path) }, 1, 8, function()
        nav.peek_link()

        local winid = vim.api.nvim_get_current_win()
        local bufnr = vim.api.nvim_win_get_buf(winid)
        local config = vim.api.nvim_win_get_config(winid)

        asserts.equals('editor', config.relative)
        asserts.equals('markdown', vim.bo[bufnr].filetype)
        asserts.equals('# Linked Note', vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])

        vim.api.nvim_win_close(winid, true)
      end)
    end)
  end)

  it('builds a markdown outline from headings and links', function()
    package.loaded['custom.markdown_nav'] = nil
    local nav = require 'custom.markdown_nav'

    with_markdown_buffer(
      {
        '# Project Notes',
        '',
        'Read [the guide](docs/guide.md) and [[Daily Note|today]].',
        '',
        '## Details',
        'See [reference][docs] and this footnote[^1].',
        '',
        '[docs]: docs/reference.md',
        '[^1]: Footnote body, not a link target.',
      },
      1,
      0,
      function(bufnr)
        local items = nav.outline_items(bufnr)

        asserts.equals(5, #items)
        asserts.same({ 'heading', 'link', 'wiki', 'heading', 'reference' }, vim.tbl_map(function(item) return item.kind end, items))
        asserts.equals('Project Notes', items[1].text)
        asserts.equals('docs/guide.md', items[2].target)
        asserts.equals('Daily Note', items[3].target)
        asserts.equals('Details', items[4].text)
        asserts.equals('docs/reference.md', items[5].target)
      end
    )
  end)

  it('configures the markdown outline picker with a preview-visible layout', function()
    package.loaded['custom.markdown_nav'] = nil
    local nav = require 'custom.markdown_nav'
    local picker_opts

    with_package_stub('telescope.pickers', {
      new = function(_, opts)
        picker_opts = opts
        return { find = function() end }
      end,
    }, function()
      with_package_stub('telescope.finders', {
        new_table = function(opts) return opts end,
      }, function()
        with_package_stub('telescope.previewers', {
          new_buffer_previewer = function(opts) return opts end,
        }, function()
          with_package_stub('telescope.previewers.utils', {
            highlighter = function() end,
          }, function()
            with_package_stub('telescope.actions', {
              close = function() end,
              select_default = { replace = function() end },
            }, function()
              with_package_stub('telescope.actions.state', {
                get_selected_entry = function() return { value = nil } end,
              }, function()
                with_package_stub('telescope.sorters', {
                  Sorter = { new = function(_, opts) return opts end },
                }, function()
                  with_markdown_buffer({ '# Notes', '', 'Read [guide](guide.md).' }, 1, 0, function() nav.outline() end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)

    asserts.equals('Markdown Outline', picker_opts.prompt_title)
    asserts.equals('ascending', picker_opts.sorting_strategy)
    asserts.equals('flex', picker_opts.layout_strategy)
    asserts.equals(1, picker_opts.layout_config.horizontal.preview_cutoff)
    asserts.equals(1, picker_opts.layout_config.vertical.preview_cutoff)
    asserts.equals('Markdown Preview', picker_opts.previewer.title)
  end)

  it('configures markdown-preview for WSL browser launch', function()
    with_os_release('6.18.33.1-microsoft-standard-WSL2', function()
      local preview = spec_by_plugin(reload_markdown_specs(), 'iamcco/markdown-preview.nvim')

      preview.init()

      asserts.same({ 'markdown' }, vim.g.mkdp_filetypes)
      asserts.equals(0, vim.g.mkdp_auto_start)
      asserts.equals(1, vim.g.mkdp_auto_close)
      asserts.equals(0, vim.g.mkdp_refresh_slow)
      asserts.equals(1, vim.g.mkdp_echo_preview_url)
      asserts.equals('OpenMarkdownPreview', vim.g.mkdp_browserfunc)
      asserts.equals(1, vim.fn.exists '*OpenMarkdownPreview')
    end)
  end)

  it('keeps markdown-preview browser defaults outside WSL', function()
    with_os_release('23.6.0', function()
      local preview = spec_by_plugin(reload_markdown_specs(), 'iamcco/markdown-preview.nvim')

      preview.init()

      asserts.same({ 'markdown' }, vim.g.mkdp_filetypes)
      asserts.falsy(vim.g.mkdp_echo_preview_url)
      asserts.falsy(vim.g.mkdp_browserfunc)
      asserts.equals(0, vim.fn.exists '*OpenMarkdownPreview')
    end)
  end)

  it('enables image.nvim only on graphics-capable non-WSL terminals', function()
    with_os_release('23.6.0', function()
      with_env({
        KITTY_WINDOW_ID = '',
        NVIM_IMAGE_SUPPORT = '',
        TERM = 'xterm-256color',
        TERM_PROGRAM = 'ghostty',
        WEZTERM_PANE = '',
      }, function()
        local image = spec_by_plugin(reload_markdown_specs(), '3rd/image.nvim')

        asserts.truthy(image)
        asserts.equals(true, image.cond())
        asserts.equals('kitty', image.opts.backend)
        asserts.equals('magick_cli', image.opts.processor)
        asserts.equals(true, image.opts.integrations.markdown.only_render_image_at_cursor)
      end)
    end)
  end)

  it('enables image.nvim inside tmux on macOS', function()
    with_os_release('23.6.0', function()
      local original_os_uname = vim.uv.os_uname
      vim.uv.os_uname = function() return { release = '23.6.0', sysname = 'Darwin' } end

      with_env({
        KITTY_WINDOW_ID = '',
        NVIM_IMAGE_SUPPORT = '',
        TERM = 'tmux-256color',
        TERM_PROGRAM = 'tmux',
        TMUX = '/private/tmp/tmux-501/default,123,0',
        WEZTERM_PANE = '',
      }, function()
        local image = spec_by_plugin(reload_markdown_specs(), '3rd/image.nvim')

        asserts.equals(true, image.cond())
      end)

      vim.uv.os_uname = original_os_uname
    end)
  end)

  it('enables image.nvim with an explicit override', function()
    with_os_release('6.18.33.1-microsoft-standard-WSL2', function()
      with_env({
        KITTY_WINDOW_ID = '',
        NVIM_IMAGE_SUPPORT = '1',
        TERM = 'tmux-256color',
        TERM_PROGRAM = 'tmux',
        TMUX = '',
        WEZTERM_PANE = '',
      }, function()
        local image = spec_by_plugin(reload_markdown_specs(), '3rd/image.nvim')

        asserts.equals(true, image.cond())
      end)
    end)
  end)

  it('enables image.nvim under WSL when terminal graphics variables are present', function()
    with_os_release('6.18.33.1-microsoft-standard-WSL2', function()
      with_env({
        KITTY_WINDOW_ID = '1',
        NVIM_IMAGE_SUPPORT = '',
        TERM = 'xterm-kitty',
        TERM_PROGRAM = 'ghostty',
        WEZTERM_PANE = '',
      }, function()
        local image = spec_by_plugin(reload_markdown_specs(), '3rd/image.nvim')

        asserts.equals(true, image.cond())
      end)
    end)
  end)

  it('disables image.nvim under WSL without terminal graphics support', function()
    with_os_release('6.18.33.1-microsoft-standard-WSL2', function()
      with_env({
        KITTY_WINDOW_ID = '',
        NVIM_IMAGE_SUPPORT = '',
        TERM = 'tmux-256color',
        TERM_PROGRAM = 'tmux',
        TMUX = '',
        WEZTERM_PANE = '',
      }, function()
        local image = spec_by_plugin(reload_markdown_specs(), '3rd/image.nvim')

        asserts.equals(false, image.cond())
      end)
    end)
  end)
end)
