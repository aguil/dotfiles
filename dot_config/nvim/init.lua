--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

if vim.fn.has 'win32' == 1 then
  vim.env.GIT_SSH_COMMAND = 'C:/Windows/System32/OpenSSH/ssh.exe -oBatchMode=yes'

  local nvim_bin = vim.fn.stdpath('config') .. '/bin'
  if vim.fn.isdirectory(nvim_bin) == 1 and not string.find(vim.env.PATH or '', nvim_bin, 1, true) then
    vim.env.PATH = nvim_bin .. ';' .. (vim.env.PATH or '')
  end

  local local_app_data = vim.env.LOCALAPPDATA
  if local_app_data and local_app_data ~= '' then
    local mise_dirs = {}

    local node_installs = vim.fn.glob(local_app_data .. '/mise/installs/node/*', false, true)
    if #node_installs > 0 then
      table.sort(node_installs)
      table.insert(mise_dirs, node_installs[#node_installs])
    end

    table.insert(mise_dirs, local_app_data .. '/mise/bin')
    table.insert(mise_dirs, local_app_data .. '/mise/shims')

    for _, dir in ipairs(mise_dirs) do
      if vim.fn.isdirectory(dir) == 1 and not string.find(vim.env.PATH or '', dir, 1, true) then
        vim.env.PATH = dir .. ';' .. (vim.env.PATH or '')
      end
    end
  end
end

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = false

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
-- vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-guide-options`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic Config & Keymaps
-- See :help vim.diagnostic.Opts
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },

  -- Can switch between these as you prefer
  virtual_text = true, -- Text shows up at the end of the line
  virtual_lines = false, -- Teest shows up underneath the line, with virtual lines

  -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
  jump = { float = true },
}

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:\n' .. out) end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added via a link or github org/name. To run setup automatically, use `opts = {}`
  { 'NMAC427/guess-indent.nvim', opts = {} },

  -- Alternatively, use `config = function() ... end` for full control over the configuration.
  -- If you prefer to call `setup` explicitly, use:
  --    {
  --        'lewis6991/gitsigns.nvim',
  --        config = function()
  --            require('gitsigns').setup({
  --                -- Your gitsigns configuration here
  --            })
  --        end,
  --    }
  --
  -- Here is a more advanced example where we pass configuration
  -- options to `gitsigns.nvim`.
  --
  -- See `:help gitsigns` to understand what the configuration keys do
  -- gitsigns.nvim and jjsigns.nvim are configured in lua/custom/plugins/git.lua
  -- (git-only vs jj-aware gutters respectively).

  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      -- delay between pressing a key and opening which-key (milliseconds)
      delay = 0,
      icons = { mappings = vim.g.have_nerd_font },

      -- Document existing key chains
      spec = {
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>g', group = 'Git / jj' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      },
    },
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    -- By default, Telescope is included and acts as your picker for everything.

    -- If you would like to switch to a different picker (like snacks, or fzf-lua)
    -- you can disable the Telescope plugin by setting enabled to false and enable
    -- your replacement picker by requiring it explicitly (e.g. 'custom.plugins.snacks')

    -- Note: If you customize your config for yourself,
    -- it’s best to remove the Telescope plugin config entirely
    -- instead of just disabling it here, to keep your config clean.
    enabled = true,
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function() return vim.fn.executable 'make' == 1 end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        -- defaults = {
        --   mappings = {
        --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        --   },
        -- },
        -- pickers = {}
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- This runs on LSP attach per buffer (see main LSP attach function in 'neovim/nvim-lspconfig' config for more info,
      -- it is better explained there). This allows easily switching between pickers if you prefer using something else!
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
        callback = function(event)
          local buf = event.buf
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          local function safe_jump(method, label)
            return function()
              if vim.bo[event.buf].filetype ~= 'kotlin' then
                vim.notify('[kotlin] Kotlin jump mappings are only active in kotlin buffers', vim.log.levels.INFO)
                return
              end

              local offset_encoding = (client and client.offset_encoding) or 'utf-16'
              local symbol_under_cursor = vim.fn.expand '<cword>'
              local params = vim.lsp.util.make_position_params(nil, offset_encoding)
              vim.lsp.buf_request(event.buf, method, params, function(err, result, context)
                if err then
                  vim.notify(string.format('[kotlin] %s request failed: %s', label, err.message or tostring(err)), vim.log.levels.ERROR)
                  return
                end

                local function to_items(raw)
                  if raw == nil or raw == vim.NIL or vim.tbl_isempty(raw) then return {} end
                  return vim.lsp.util.locations_to_items(raw, (client and client.offset_encoding) or 'utf-16')
                end

                local function is_jar_reference(value)
                  return type(value) == 'string' and value:match('^jar://')
                end

                local function dedupe(list)
                  local seen = {}
                  local out = {}
                  for _, value in ipairs(list) do
                    if type(value) == 'string' and value ~= '' and not seen[value] then
                      seen[value] = true
                      out[#out + 1] = value
                    end
                  end
                  return out
                end

                local function normalize_entry(entry_path)
                  if type(entry_path) ~= 'string' then
                    return ''
                  end
                  return entry_path:gsub('^/', '')
                end

                local function decode_jar_path(path)
                  if type(path) ~= 'string' then
                    return ''
                  end

                  if vim.uri_to_fname then
                    local ok, decoded = pcall(vim.uri_to_fname, path)
                    if ok and type(decoded) == 'string' and decoded ~= '' then
                      return decoded
                    end
                  end

                  return path
                end

                local function open_in_jump_buffer_with_file(path)
                  local previous_buf = vim.api.nvim_get_current_buf()
                  if vim.api.nvim_buf_is_valid(previous_buf) then
                    vim.bo[previous_buf].buflisted = true
                    if vim.bo[previous_buf].bufhidden == '' then
                      vim.bo[previous_buf].bufhidden = 'hide'
                    end
                  end
                  vim.cmd('keepalt hide edit ' .. vim.fn.fnameescape(path))
                  local current_buf = vim.api.nvim_get_current_buf()
                  if vim.api.nvim_buf_is_valid(current_buf) then
                    vim.bo[current_buf].buflisted = true
                  end
                end

                local function open_in_jump_buffer_with_buf(bufnr)
                  local previous_buf = vim.api.nvim_get_current_buf()
                  if vim.api.nvim_buf_is_valid(previous_buf) then
                    vim.bo[previous_buf].buflisted = true
                    if vim.bo[previous_buf].bufhidden == '' then
                      vim.bo[previous_buf].bufhidden = 'hide'
                    end
                  end
                  pcall(vim.api.nvim_set_current_buf, bufnr)
                  if vim.api.nvim_buf_is_valid(bufnr) then
                    vim.bo[bufnr].buflisted = true
                  end
                end

                local kotlin_allow_decompiled_fallback = true

                local function class_entry_to_fqcn(entry_path)
                  local base = normalize_entry(entry_path):gsub('%.class$', '')
                  if base == '' then
                    return ''
                  end
                  base = base:gsub('%$.*$', '')
                  return base:gsub('/', '.')
                end

                local function locate_cfr_command()
                  local candidates = {
                    vim.fn.exepath 'cfr-decompiler',
                    vim.fn.exepath 'cfr',
                    '/opt/homebrew/bin/cfr-decompiler',
                    '/opt/homebrew/bin/cfr',
                    '/usr/local/bin/cfr-decompiler',
                    '/usr/local/bin/cfr',
                    '/opt/homebrew/opt/cfr-decompiler/bin/cfr-decompiler',
                    '/opt/homebrew/opt/cfr-decompiler/bin/cfr',
                    vim.fn.expand '~/.local/bin/cfr-decompiler',
                    vim.fn.expand '~/.local/bin/cfr',
                  }

                  for _, candidate in ipairs(candidates) do
                    if candidate ~= '' and vim.fn.executable(candidate) == 1 then
                      return candidate
                    end
                  end
                  return ''
                end

                local function locate_cfr_jar()
                  local candidates = {
                    vim.fn.exepath 'cfr',
                    '/opt/homebrew/bin/cfr',
                    '/opt/homebrew/bin/cfr-decompiler',
                    '/usr/local/bin/cfr',
                    '/usr/local/bin/cfr-decompiler',
                    vim.fn.expand '~/.local/bin/cfr',
                    vim.fn.expand '~/.local/bin/cfr-decompiler',
                    vim.fn.expand '~/.local/share/cfr/cfr.jar',
                    vim.fn.expand '~/.cache/cfr/cfr.jar',
                  }

                  for _, candidate in ipairs(candidates) do
                    if candidate ~= '' and vim.fn.filereadable(candidate) == 1 then
                      if candidate:match('%.jar$') then
                        return candidate
                      end

                      local first_line = vim.fn.readfile(candidate, '', 1)[1] or ''
                      local jar_path = first_line:match('cfr[^%s]*%.jar')
                      if jar_path and vim.fn.filereadable(jar_path) == 1 then
                        return jar_path
                      end
                    end
                  end

                  for _, path in ipairs(vim.fn.split(vim.fn.glob(vim.fn.expand '~/.m2/repository/**/cfr-*.jar'), '\n')) do
                    if path ~= '' and vim.fn.filereadable(path) == 1 then
                      return path
                    end
                  end

                  return ''
                end

                local function open_readonly_text_buffer(lines, display_name, ft)
                  vim.cmd 'hide enew'
                  local bufnr = vim.api.nvim_get_current_buf()
                  vim.bo[bufnr].buftype = 'nofile'
                  vim.bo[bufnr].bufhidden = 'wipe'
                  vim.bo[bufnr].buflisted = true
                  vim.bo[bufnr].swapfile = false
                  vim.bo[bufnr].modifiable = true
                  vim.bo[bufnr].filetype = ft
                  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
                  vim.bo[bufnr].modifiable = false
                  pcall(vim.api.nvim_buf_set_name, bufnr, display_name)
                end

                local function open_decompiled_class(jar_path, entry_path, label)
                  local fqcn = class_entry_to_fqcn(entry_path)
                  if fqcn == '' then
                    return false
                  end

                  if vim.fn.executable('java') == 1 then
                    local outdir = vim.fn.tempname()
                    vim.fn.mkdir(outdir, 'p')
                    local cfr_cmd = locate_cfr_command()
                    if cfr_cmd ~= '' then
                      local cfr_result = vim.system({ cfr_cmd, jar_path, '--outputdir', outdir, '--silent', 'true' }, { text = true }):wait()
                      if cfr_result.code == 0 then
                        local java_file = outdir .. '/' .. fqcn:gsub('%.', '/') .. '.java'
                        if vim.fn.filereadable(java_file) == 1 then
                          local lines = vim.fn.readfile(java_file)
                          open_readonly_text_buffer(lines, string.format('decompiled://%s::%s.java', vim.fn.fnamemodify(jar_path, ':t'), fqcn), 'java')
                          vim.notify(string.format('[kotlin] %s target opened via CFR decompiler (%s)', label, fqcn), vim.log.levels.WARN)
                          return true
                        end
                      end
                    end

                    local cfr_jar = locate_cfr_jar()
                    if cfr_jar ~= '' then
                      local cfr_result = vim.system({ 'java', '-jar', cfr_jar, jar_path, '--outputdir', outdir, '--silent', 'true' }, { text = true }):wait()
                      if cfr_result.code == 0 then
                        local java_file = outdir .. '/' .. fqcn:gsub('%.', '/') .. '.java'
                        if vim.fn.filereadable(java_file) == 1 then
                          local lines = vim.fn.readfile(java_file)
                          open_readonly_text_buffer(lines, string.format('decompiled://%s::%s.java', vim.fn.fnamemodify(jar_path, ':t'), fqcn), 'java')
                          vim.notify(string.format('[kotlin] %s target opened via CFR decompiler (%s)', label, fqcn), vim.log.levels.WARN)
                          return true
                        end
                      end
                    end
                  end

                  if vim.fn.executable('javap') ~= 1 then
                    vim.notify('[kotlin] javap is unavailable; cannot open decompiled class fallback', vim.log.levels.WARN)
                    return false
                  end

                  local result = vim.system({ 'javap', '-classpath', jar_path, '-p', '-c', fqcn }, { text = true }):wait()
                  if result.code ~= 0 or not result.stdout or result.stdout == '' then
                    return false
                  end

                  local display_name = string.format('decompiled://%s::%s', vim.fn.fnamemodify(jar_path, ':t'), fqcn)
                  open_readonly_text_buffer(vim.fn.split(result.stdout, '\n'), display_name, 'java')
                  vim.notify(string.format('[kotlin] %s target opened via javap bytecode view (%s)', label, fqcn), vim.log.levels.WARN)
                  return true
                end

                local function class_entry_candidates(entry_candidates, original_entry, symbol_name)
                  local candidates = {}
                  local function add_candidate(value)
                    if type(value) ~= 'string' or value == '' then
                      return
                    end
                    candidates[#candidates + 1] = normalize_entry(value)
                  end

                  add_candidate(original_entry)
                  if type(symbol_name) == 'string' and symbol_name ~= '' then
                    local normalized_original = normalize_entry(original_entry)
                    if normalized_original:match '/$' then
                      add_candidate(normalized_original .. symbol_name .. '.class')
                    elseif not normalized_original:match('%.class$') and not normalized_original:match('%.kt$') and not normalized_original:match('%.java$') then
                      add_candidate(normalized_original .. '/' .. symbol_name .. '.class')
                    end
                  end
                  for _, entry in ipairs(entry_candidates) do
                    add_candidate(entry)
                    if entry:match('%.kt$') then
                      add_candidate(entry:gsub('%.kt$', '.class'))
                    elseif entry:match('%.java$') then
                      add_candidate(entry:gsub('%.java$', '.class'))
                    elseif not entry:match('%.class$') then
                      add_candidate(entry .. '.class')
                    end
                  end

                  return dedupe(candidates)
                end

                local function jump_to_zip_entry(jar_file, entry_path, item)
                  local zip_uri = string.format('zipfile://%s::%s', jar_file, normalize_entry(entry_path))
                  local ok = pcall(open_in_jump_buffer_with_file, zip_uri)
                  if not ok then
                    return false
                  end

                  local bufnr = vim.api.nvim_get_current_buf()
                  local line_count = vim.api.nvim_buf_line_count(bufnr)
                  if line_count <= 0 then
                    return false
                  end

                  local line = item.lnum or 1
                  local col = item.col or 1
                  if line < 1 then
                    line = 1
                  end
                  if line > line_count then
                    line = line_count
                  end

                  local line_text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ''
                  local max_col = #line_text + 1
                  if col < 1 then
                    col = 1
                  elseif col > max_col then
                    col = max_col
                  end

                  if pcall(vim.api.nvim_set_current_win, vim.api.nvim_get_current_win()) and pcall(vim.api.nvim_set_current_buf, bufnr) then
                    local new_col = col - 1
                    if new_col < 0 then
                      new_col = 0
                    end
                    return pcall(vim.api.nvim_win_set_cursor, 0, { line, new_col })
                  end
                  return false
                end

                local function source_entry_variants(entry_path)
                  local entries = { entry_path }
                  if entry_path:match('%.class$') then
                    local base = entry_path:gsub('%.class$', '')
                    local kt_entry = base .. '.kt'
                    local java_entry = base .. '.java'
                    local stripped = base:gsub('%$[^/\\]+$', '')
                    table.insert(entries, kt_entry)
                    table.insert(entries, java_entry)
                    if stripped ~= base then
                      table.insert(entries, stripped .. '.kt')
                      table.insert(entries, stripped .. '.java')
                    end
                  end
                  return dedupe(entries)
                end

                local function find_source_jars(jar_file)
                  local source_jars = {}
                  local seen = {}
                  local jar_dir = vim.fn.fnamemodify(jar_file, ':h')
                  local version_dir = vim.fn.fnamemodify(jar_dir, ':h')
                  local jar_name = vim.fn.fnamemodify(jar_file, ':t:r')

                  local function add_candidate(path)
                    if path == '' or seen[path] then
                      return
                    end
                    if vim.fn.filereadable(path) == 1 then
                      seen[path] = true
                      source_jars[#source_jars + 1] = path
                    end
                  end

                  add_candidate(jar_dir .. '/' .. jar_name .. '-sources.jar')
                  add_candidate(jar_dir .. '/' .. jar_name .. '-source.jar')
                  add_candidate(jar_dir .. '/' .. jar_name .. '-sources-' .. 'main.jar')
                  add_candidate(version_dir .. '/' .. jar_name .. '-sources.jar')
                  add_candidate(version_dir .. '/' .. jar_name .. '-source.jar')

                  for _, candidate in ipairs(vim.fn.split(vim.fn.glob(jar_dir .. '/*source*.jar'), '\n')) do
                    add_candidate(candidate)
                  end
                  for _, candidate in ipairs(vim.fn.split(vim.fn.glob(jar_dir .. '/*sources*.jar'), '\n')) do
                    add_candidate(candidate)
                  end
                  -- Gradle cache often stores artifact and sources in sibling hash dirs under the same version dir.
                  for _, candidate in ipairs(vim.fn.split(vim.fn.glob(version_dir .. '/*/*-sources.jar'), '\n')) do
                    add_candidate(candidate)
                  end
                  for _, candidate in ipairs(vim.fn.split(vim.fn.glob(version_dir .. '/*/*-source.jar'), '\n')) do
                    add_candidate(candidate)
                  end
                  for _, candidate in ipairs(vim.fn.split(vim.fn.glob(version_dir .. '/*/*source*.jar'), '\n')) do
                    add_candidate(candidate)
                  end

                  return source_jars
                end

                local function jump_to_jar_reference(item, label)
                  local uri = item.uri or item.filename
                  if not is_jar_reference(uri) then
                    return false
                  end

                  local jar_path, entry_path = uri:match('^jar://(.-)!/(.+)$')
                  if not jar_path or not entry_path then
                    return false
                  end

                  jar_path = decode_jar_path(jar_path)
                  entry_path = decode_jar_path(entry_path)
                  if jar_path == '' then
                    return false
                  end

                  local item_entry_path = normalize_entry(entry_path)
                  local entry_candidates = source_entry_variants(item_entry_path)
                  local source_jars = {}

                  if jar_path:match('%-sources%.jar$') or jar_path:match('%-source%.jar$') then
                    source_jars = { jar_path }
                  else
                    source_jars = find_source_jars(jar_path)
                  end

                  if #source_jars > 0 then
                    for _, source_jar in ipairs(source_jars) do
                      for _, candidate_entry in ipairs(entry_candidates) do
                        if jump_to_zip_entry(source_jar, candidate_entry, item) then
                          local entry_name = vim.fn.fnamemodify(source_jar, ':t')
                          local line = item.lnum or 0
                          if line < 1 then
                            line = 1
                          end
                          vim.notify(
                            string.format('[kotlin] %s target resolved from source JAR %s::%s (line %d)', label, entry_name, candidate_entry, line),
                            vim.log.levels.INFO
                          )
                          return true
                        end
                      end
                    end
                  end

                  if kotlin_allow_decompiled_fallback then
                    local decompile_candidates = class_entry_candidates(entry_candidates, item_entry_path, symbol_under_cursor)
                    for _, class_entry in ipairs(decompile_candidates) do
                      if class_entry:match('%.class$') and open_decompiled_class(jar_path, class_entry, label) then
                        return true
                      end
                    end
                  end

                  return false
                end

                local items = to_items(result)
                if #items == 0 then
                  vim.notify(string.format('[kotlin] No %s targets found', label), vim.log.levels.INFO)
                  return
                end

                local saw_jar_target = false
                for _, item in ipairs(items) do
                  if is_jar_reference(item.filename) or is_jar_reference(item.uri) then
                    saw_jar_target = true
                    if jump_to_jar_reference(item, label) then
                      return
                    end
                  else
                    local bufnr = vim.fn.bufnr(item.filename, false)
                    if bufnr == -1 then
                      bufnr = vim.fn.bufnr(item.filename, true)
                    end
                    if bufnr ~= -1 then
                      local ok = pcall(vim.fn.bufload, bufnr)
                      if ok then
                        local line_count = vim.api.nvim_buf_line_count(bufnr)
                        local line = item.lnum or 1
                        local col = item.col or 1
                        if line < 1 then
                          line = 1
                        end
                        if line_count <= 0 then
                          line_count = 1
                        end
                        if line > line_count then
                          line = line_count
                        end

                        local line_text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ''
                        local max_col = #line_text + 1
                        if col < 1 then
                          col = 1
                        elseif col > max_col then
                          col = max_col
                        end

                        open_in_jump_buffer_with_buf(bufnr)
                        local new_col = col - 1
                        if new_col < 0 then
                          new_col = 0
                        end
                        vim.api.nvim_win_set_cursor(0, { line, new_col })
                        return
                      end
                    end
                  end
                end

                if saw_jar_target then
                  vim.notify(
                    string.format(
                      '[kotlin] %s targets were not jumpable in this session. Tried source JAR entries and decompiled-class fallback, but no readable target was found.',
                      label
                    ),
                    vim.log.levels.INFO
                  )
                else
                  vim.notify(string.format('[kotlin] %s targets were not jumpable', label), vim.log.levels.INFO)
                end
              end)
            end
          end

          -- Find references for the word under your cursor.
          vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })

          -- Jump to the implementation of the word under your cursor.
          -- Useful when your language has ways of declaring types without an actual implementation.
          vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })

          -- Jump to the definition of the word under your cursor.
          -- This is where a variable was first declared, or where a function is defined, etc.
          -- To jump back, press <C-t>.
          vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })

          -- Fuzzy find all the symbols in your current document.
          -- Symbols are things like variables, functions, types, etc.
          vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })

          -- Fuzzy find all the symbols in your current workspace.
          -- Similar to document symbols, except searches over your entire project.
          vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })

          -- Jump to the type of the word under your cursor.
          -- Useful when you're not sure what type a variable is and you want to see
          -- the definition of its *type*, not where it was *defined*.
          vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })

          -- Kotlin's server + Telescope picker can produce invalid cursor targets in Neovim 0.12.
          -- Use native LSP jump handlers for Kotlin buffers to avoid crashes on bad ranges.
          if client and client.name == 'kotlin_lsp' then
            vim.keymap.set('n', '<leader>kg', safe_jump('textDocument/definition', 'definition'), { buffer = buf, desc = '[Kotlin] [G]oto [D]efinition (source/jar source)' })
            vim.keymap.set('n', 'grd', safe_jump('textDocument/definition', 'definition'), { buffer = buf, desc = '[Kotlin] [G]oto [D]efinition' })
            vim.keymap.set('n', 'gri', safe_jump('textDocument/implementation', 'implementation'), { buffer = buf, desc = '[Kotlin] [G]oto [I]mplementation' })
            vim.keymap.set('n', 'grt', safe_jump('textDocument/typeDefinition', 'type definition'), { buffer = buf, desc = '[Kotlin] [G]oto [T]ype Definition' })
            vim.keymap.set('n', 'grr', safe_jump('textDocument/references', 'references'), { buffer = buf, desc = '[Kotlin] [G]oto [R]eferences' })
          end
        end,
      })

      -- Override default behavior and theme when searching
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set(
        'n',
        '<leader>s/',
        function()
          builtin.live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        { desc = '[S]earch [/] in Open Files' }
      )

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Plugins
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      { 'mason-org/mason.nvim', opts = {} },
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      local lspc = require('lspconfig')
      local kotlin_root_pattern = lspc.util.root_pattern('build.gradle', 'build.gradle.kts', 'pom.xml', '.git')
      local kotlin_root_markers = { 'build.gradle', 'build.gradle.kts', 'pom.xml', '.git' }

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --  See `:help lsp-config` for information about keys and how to configure
      -- NOTE: Kotlin LSP is installed/managed outside Mason.
      -- Use a manual install of `kotlin-lsp` (or `kotlin-ls`) and add it to PATH.
      local kotlin_lsp_binary = ''
      for _, binary in ipairs { 'kotlin-lsp', 'kotlin-ls', 'kotlin-language-server' } do
        if kotlin_lsp_binary == '' then kotlin_lsp_binary = vim.fn.exepath(binary) end
      end
      if kotlin_lsp_binary == '' then
        for _, candidate in ipairs {
          '/opt/homebrew/bin/kotlin-lsp',
          '/opt/homebrew/bin/kotlin-ls',
          '/usr/local/bin/kotlin-lsp',
          '/usr/local/bin/kotlin-ls',
        } do
          if kotlin_lsp_binary == '' and vim.fn.filereadable(candidate) == 1 then kotlin_lsp_binary = candidate end
        end
      end

      local servers = {
        jsonls = {},
        yamlls = {},
        html = {},
        cssls = {},
      }

      local kotlin_config = nil
      if kotlin_lsp_binary ~= '' then
        kotlin_config = {
          -- Official kotlin-lsp recommends stdio mode for nvim.
          cmd = { kotlin_lsp_binary, '--stdio' },
          single_file_support = true,
          root_dir = function(fname)
            local path = (type(fname) == 'string' and fname ~= '' and fname) or vim.api.nvim_buf_get_name(0)
            return kotlin_root_pattern(path) or (path ~= '' and vim.fs.dirname(path)) or vim.uv.cwd()
          end,
          filetypes = { 'kotlin' },
          -- nvim-lspconfig 0.1x path:
          root_markers = kotlin_root_markers,
        }

        local ok, configs = pcall(require, 'lspconfig.configs')
        if ok and not configs.kotlin_lsp then
          configs.kotlin_lsp = {
            default_config = vim.tbl_deep_extend('force', kotlin_config, {
              capabilities = capabilities,
            }),
          }
        end

        if lspc.kotlin_lsp and lspc.kotlin_lsp.setup then
          lspc.kotlin_lsp.setup {}
          vim.lsp.enable 'kotlin_lsp'
        else
          servers.kotlin_lsp = vim.tbl_deep_extend('force', kotlin_config, {
            capabilities = capabilities,
          })
        end
      else
        vim.notify('[kotlin] kotlin-lsp not found on PATH. Install it manually and set `kotlin-lsp` (or `kotlin-ls`) in PATH.', vim.log.levels.WARN)
      end

      if vim.fn.executable 'dart' == 1 then
        servers.dartls = {
          cmd = { 'dart', 'language-server', '--protocol=lsp' },
          filetypes = { 'dart' },
          init_options = {
            closingLabels = true,
            outline = true,
            flutterOutline = true,
            suggestFromUnimportedLibraries = true,
          },
          settings = {
            dart = {
              completeFunctionCalls = true,
              showTodos = true,
            },
          },
        }
      end

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      --
      -- You can press `g?` for help in this menu.
      local ensure_installed = {
        'lua-language-server', -- Lua Language server
        'stylua', -- Used to format Lua code
        'ktlint',
        'dart-debug-adapter',
      }

      if vim.fn.executable 'npm' == 1 then
        vim.list_extend(ensure_installed, {
          'yaml-language-server',
          'json-lsp',
          'html-lsp',
          'css-lsp',
          'typescript-language-server',
          'eslint_d',
          'prettierd',
        })
      end

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      for name, server in pairs(servers) do
        server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
        vim.lsp.config(name, server)
        vim.lsp.enable(name)
      end

      if kotlin_config then
        vim.api.nvim_create_autocmd('FileType', {
          pattern = 'kotlin',
          callback = function()
            local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
            local clients = get_clients { name = 'kotlin_lsp', bufnr = vim.api.nvim_get_current_buf() }
            if #clients == 0 then vim.lsp.enable 'kotlin_lsp' end
          end,
        })
      end

      vim.api.nvim_create_user_command('KotlinLspInfo', function()
        local lines = { 'Kotlin LSP information:' }
        local to_bool = function(v)
          if v == nil then return 'unknown' end
          if v == true then return 'yes' end
          if v == false then return 'no' end
          return type(v) == 'table' and 'yes' or tostring(v)
        end

        local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
        if not get_clients then
          vim.notify('[kotlin] Neovim LSP client API not available', vim.log.levels.WARN)
          return
        end

        local clients = get_clients { name = 'kotlin_lsp' }
        local current_buf_clients = get_clients { name = 'kotlin_lsp', bufnr = vim.api.nvim_get_current_buf() }
        local client_count = #clients
        local current_count = #current_buf_clients
        local cfr_candidate = vim.fn.exepath 'cfr-decompiler'
        if cfr_candidate == '' then
          cfr_candidate = vim.fn.exepath 'cfr'
        end
        if cfr_candidate == '' then
          for _, candidate in ipairs {
            '/opt/homebrew/bin/cfr-decompiler',
            '/opt/homebrew/bin/cfr',
            '/usr/local/bin/cfr-decompiler',
            '/usr/local/bin/cfr',
            '/opt/homebrew/opt/cfr-decompiler/bin/cfr-decompiler',
            '/opt/homebrew/opt/cfr-decompiler/bin/cfr',
            vim.fn.expand '~/.local/bin/cfr-decompiler',
            vim.fn.expand '~/.local/bin/cfr',
            vim.fn.expand '~/.local/share/cfr/cfr.jar',
            vim.fn.expand '~/.cache/cfr/cfr.jar',
          } do
            if vim.fn.executable(candidate) == 1 or vim.fn.filereadable(candidate) == 1 then
              cfr_candidate = candidate
              break
            end
          end
        end
        local cfr_status = cfr_candidate ~= '' and ('yes (' .. cfr_candidate .. ')') or 'no (javap fallback only)'
        table.insert(lines, string.format('Binary: %s', kotlin_lsp_binary ~= '' and kotlin_lsp_binary or '<not configured>'))
        table.insert(lines, string.format('Decompiler (CFR): %s', cfr_status))
        table.insert(lines, string.format('lspconfig config: %s', (lspc.kotlin_lsp and 'kotlin_lsp present') or 'not present (custom registration only)'))
        table.insert(lines, string.format('Clients: total=%d, current_buffer=%d', client_count, current_count))
        table.insert(lines, string.format('Current filetype: %s', vim.bo.filetype))

        if current_count == 0 then
          table.insert(lines, 'Current buffer: no kotlin_lsp client attached')
        end

        for _, client in ipairs(clients) do
          local root = client.config and client.config.root_dir or '<unknown>'
          local cmd = client.config and client.config.cmd or {}
          local caps = client.server_capabilities or {}
          table.insert(lines, string.format('[%s] id=%d, root=%s', client.name, client.id, root))
          table.insert(lines, string.format('  cmd=%s', table.concat(vim.tbl_map(tostring, cmd), ' ')))
          table.insert(lines, string.format('  referencesProvider=%s', to_bool(caps.referencesProvider)))
          table.insert(lines, string.format('  implementationProvider=%s', to_bool(caps.implementationProvider)))
          table.insert(lines, string.format('  definitionProvider=%s', to_bool(caps.definitionProvider)))
          table.insert(lines, string.format('  completionProvider=%s', to_bool(caps.completionProvider)))
        end

        if #lines == 6 and #clients == 0 then
          table.insert(lines, 'Tip: reopen a Kotlin buffer after restart, then run :KotlinLspInfo again')
        end

        vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
      end, { desc = 'Show Kotlin LSP client and attachment details' })

      -- Special Lua Config, as recommended by neovim help docs
      vim.lsp.config('lua_ls', {
        on_init = function(client)
          if client.workspace_folders then
            local path = client.workspace_folders[1].name
            if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
          end

          client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
            runtime = {
              version = 'LuaJIT',
              path = { 'lua/?.lua', 'lua/?/init.lua' },
            },
            workspace = {
              checkThirdParty = false,
              -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
              --  See https://github.com/neovim/nvim-lspconfig/issues/3189
              library = vim.api.nvim_get_runtime_file('', true),
            },
          })
        end,
        settings = {
          Lua = {},
        },
      })
      vim.lsp.enable 'lua_ls'
    end,
  },

  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-neotest/neotest-python',
      'marilari88/neotest-vitest',
    },
    config = function()
      local neotest = require 'neotest'
      neotest.setup {
        default_strategy = 'integrated',
        adapters = {
          require 'neotest-python' {
            runner = 'pytest',
            python = '.venv/bin/python',
            -- python = function() return vim.fn.exepath 'python3' end,
            -- pytest_command = function() return { vim.fn.exepath 'python3', '-m', 'pytest' } end,
            -- pytest_command = { 'python3', '-m', 'pytest' },
          },
          require 'neotest-vitest',
        },
      }
      -- vim.keymap.set('n', '<leader>tn', neotest.run.run, { desc = 'Test nearest' })
      -- vim.keymap.set('n', '<leader>tf', function() neotest.run.run(vim.fn.expand '%:p') end, { desc = 'Test file' })
      vim.keymap.set('n', '<leader>tn', function() neotest.run.run(vim.fn.getcwd()) end, { desc = 'Run tests (project)' })
      vim.keymap.set('n', '<leader>tf', function() neotest.run.run(vim.fn.expand '%:p') end, { desc = 'Run test file' })
      vim.keymap.set('n', '<leader>to', neotest.output.open, { desc = 'Test output' })
      vim.keymap.set('n', '<leader>tO', neotest.output_panel.toggle, { desc = 'Test panel' })
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function() require('conform').format { async = true, lsp_format = 'fallback' } end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        kotlin = { 'ktlint' },
        dart = { 'dart_format' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then return end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
        opts = {},
      },
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        -- 'default' (recommended) for mappings similar to built-in completions
        --   <c-y> to accept ([y]es) the completion.
        --    This will auto-import if your LSP supports it.
        --    This will expand snippets if the LSP sent a snippet.
        -- 'super-tab' for tab to accept
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- For an understanding of why the 'default' preset is recommended,
        -- you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        --
        -- All presets have the following mappings:
        -- <tab>/<s-tab>: move to right/left of your snippet expansion
        -- <c-space>: Open menu or open docs if already open
        -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
        -- <c-e>: Hide menu
        -- <c-k>: Toggle signature help
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        preset = 'default',

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets' },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- By default, we use the Lua implementation instead, but you may enable
      -- the rust implementation via `'prefer_rust_with_warning'`
      --
      -- See :h blink-cmp-config-fuzzy for more information
      fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },

  {
    "juxt/nvim-allium",
    event = "VeryLazy",
    opts = {},
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
  },

  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'nvim-mini/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function() return '%2l:%-2v' end

      -- ... and there is more!
      --  Check out: https://github.com/nvim-mini/mini.nvim
    end,
  },

  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    config = function()
      local parsers = { 'bash', 'c', 'css', 'dart', 'diff', 'groovy', 'html', 'java', 'javascript', 'json', 'kotlin', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml' }
      local filetypes = vim.list_extend(vim.deepcopy(parsers), { 'javascriptreact', 'typescriptreact' })
      if vim.fn.executable('tree-sitter') == 1 then
        require('nvim-treesitter').install(parsers)
      end
      vim.api.nvim_create_autocmd('FileType', {
        pattern = filetypes,
        callback = function() vim.treesitter.start() end,
      })
      require("nvim-treesitter").setup({
        highlight = { enable = true },
      })
    end,
  },

  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug',
  -- require 'kickstart.plugins.indent_line',
  -- require 'kickstart.plugins.lint',
  -- require 'kickstart.plugins.autopairs',
  -- require 'kickstart.plugins.neo-tree',
  -- require 'kickstart.plugins.gitsigns', -- adds gitsigns recommend keymaps

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    This is the easiest way to modularize your config.
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  { import = 'custom.plugins' },
  --
  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, {
  git = {
    url_format = 'https://github.com/%s.git',
  },
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
