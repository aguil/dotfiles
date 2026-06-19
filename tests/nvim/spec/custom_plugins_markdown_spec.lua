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
    asserts.equals(true, render.opts.completions.lsp.enabled)

    asserts.truthy(preview)
    asserts.same({ 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' }, preview.cmd)
    asserts.same({ 'markdown' }, preview.ft)
    asserts.equals('cd app && npm install', preview.build)
    asserts.equals('<leader>mp', preview.keys[1][1])
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
        KITTY_WINDOW_ID = nil,
        TERM = 'xterm-256color',
        TERM_PROGRAM = 'ghostty',
        WEZTERM_PANE = nil,
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

  it('disables image.nvim under WSL even with terminal graphics variables', function()
    with_os_release('6.18.33.1-microsoft-standard-WSL2', function()
      with_env({
        KITTY_WINDOW_ID = '1',
        TERM = 'xterm-kitty',
        TERM_PROGRAM = 'ghostty',
        WEZTERM_PANE = nil,
      }, function()
        local image = spec_by_plugin(reload_markdown_specs(), '3rd/image.nvim')

        asserts.equals(false, image.cond())
      end)
    end)
  end)
end)
