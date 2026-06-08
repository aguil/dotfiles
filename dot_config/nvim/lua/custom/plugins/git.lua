local vcs = require 'custom.vcs'

local function notify_no_git(feature)
  vim.notify(feature .. ' needs a Git workspace (.git). jj-only repo: use :J or <leader>gj.', vim.log.levels.WARN)
end

local function open_jj_status()
  require('jj.cmd').status()
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(0) then
      vim.cmd.resize(12)
    end
  end)
end

local function open_vcs_ui()
  local kind = vcs.workspace_kind(0)
  if kind == 'git' then
    require('neogit').open()
  elseif kind == 'jj' then
    open_jj_status()
  else
    vim.notify('Not inside a Git or jj repository.', vim.log.levels.WARN)
  end
end

local function split_lines(stdout)
  if stdout:sub(-1) == '\n' then
    stdout = stdout:sub(1, -2)
  end
  if stdout == '' then
    return {}
  end

  local lines = {}
  for line in (stdout .. '\n'):gmatch '(.-)\n' do
    table.insert(lines, line)
  end
  return lines
end

local function system_result(cmd, cwd)
  local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
  return split_lines(result.stdout or ''), result.code
end

local function system_async(cmd, cwd, callback)
  vim.system(cmd, { cwd = cwd, text = true }, function(result)
    local lines = split_lines(result.stdout or '')
    local stderr = (result.stderr or ''):gsub('%s+$', '')
    vim.schedule(function()
      callback(lines, result.code, stderr)
    end)
  end)
end

local function system_ok(cmd, cwd)
  local _, code = system_result(cmd, cwd)
  return code == 0
end

local function shell_join(cmd)
  return table.concat(vim.tbl_map(vim.fn.shellescape, cmd), ' ')
end

local function default_branch_candidates()
  return vim.g.dot_vcs_default_branches or { 'master', 'main' }
end

local function find_git_default_branch(root)
  local lines, code = system_result({
    'git',
    'symbolic-ref',
    '--quiet',
    '--short',
    'refs/remotes/origin/HEAD',
  }, root)
  local origin_head = lines[1]
  if code == 0 and origin_head and origin_head ~= '' then
    return origin_head
  end

  for _, branch in ipairs(default_branch_candidates()) do
    if system_ok({ 'git', 'rev-parse', '--verify', '--quiet', branch }, root) then
      return branch
    end
    if system_ok({ 'git', 'rev-parse', '--verify', '--quiet', 'origin/' .. branch }, root) then
      return 'origin/' .. branch
    end
  end
end

local function find_jj_default_branch(root)
  for _, branch in ipairs(default_branch_candidates()) do
    if system_ok({ 'jj', 'log', '--no-graph', '--limit', '1', '-r', branch, '-T', 'commit_id' }, root) then
      return branch
    end
    local remote_branch = branch .. '@origin'
    if system_ok({
      'jj',
      'log',
      '--no-graph',
      '--limit',
      '1',
      '-r',
      remote_branch,
      '-T',
      'commit_id',
    }, root) then
      return remote_branch
    end
  end
end

local function stat_path(line)
  line = line:gsub('\27%[[%d;]*m', '')
  local path = line:match '^%s*(.-)%s*|'
  if not path or path == '' then
    return nil
  end

  -- Git/jj rename stats use `old => new`; open the destination side.
  path = path:gsub('^%s+', ''):gsub('%s+$', '')
  local prefix, renamed, suffix = path:match '^(.-){.-%s*=>%s*(.-)}(.*)$'
  if renamed then
    path = prefix .. renamed .. suffix
  else
    path = path:match '=>%s*(.+)$' or path
  end
  return path
end

local function open_branch_changes()
  local kind = vcs.workspace_kind(0)
  if kind == 'none' then
    vim.notify('Not inside a Git or jj repository.', vim.log.levels.WARN)
    return
  end

  local current_file = vim.api.nvim_buf_get_name(0)
  local root = vcs.find_root(current_file ~= '' and current_file or vim.fn.getcwd(0))
  if not root then
    vim.notify('Not inside a Git or jj repository.', vim.log.levels.WARN)
    return
  end

  local base = kind == 'jj' and find_jj_default_branch(root) or find_git_default_branch(root)
  if not base then
    vim.notify('Could not find default branch. Set vim.g.dot_vcs_default_branches.', vim.log.levels.WARN)
    return
  end

  local jj_target = kind == 'jj' and '@' or nil
  local range = kind == 'jj' and base .. '..' .. jj_target or base .. '...HEAD'
  local name_cmd = kind == 'jj' and { 'jj', '--color', 'never', 'diff', '--name-only', '-r', range }
    or { 'git', 'diff', '--no-color', '--name-only', base .. '...HEAD' }

  system_async(name_cmd, root, function(paths, code, stderr)
    if code ~= 0 then
      local detail = stderr ~= '' and (': ' .. stderr) or '.'
      vim.notify('Could not load branch changes for ' .. base .. detail, vim.log.levels.WARN)
      return
    end

    local entries = {}
    for _, path in ipairs(paths) do
      if path ~= '' then
        table.insert(entries, path)
      end
    end

    if vim.tbl_isempty(entries) then
      vim.notify('No branch change files found for ' .. base .. '.', vim.log.levels.INFO)
      return
    end

    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local make_entry = require 'telescope.make_entry'
    local previewers = require 'telescope.previewers'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'
    local file_entry_maker = make_entry.gen_from_file { cwd = root }
    local delta_available = vim.fn.executable 'delta' == 1
    local diff_previewer = previewers.new_buffer_previewer {
      title = 'Branch diff',
      define_preview = function(self, entry)
        local path = entry.value
        local diff_cmd = kind == 'jj' and { 'jj', '--color', 'never', 'diff', '--git', '-r', range, '--', path }
          or { 'git', 'diff', '--no-color', range, '--', path }

        if delta_available then
          local command = shell_join(diff_cmd) .. ' | ' .. shell_join { 'delta', '--default-language', 'bash' }
          vim.api.nvim_buf_call(self.state.bufnr, function()
            vim.fn.termopen(command, { cwd = root })
          end)
          return
        end

        vim.bo[self.state.bufnr].filetype = 'diff'
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { 'Loading diff for ' .. path .. '...' })
        system_async(diff_cmd, root, function(diff_lines, diff_code, diff_stderr)
          if not vim.api.nvim_buf_is_valid(self.state.bufnr) then
            return
          end
          if diff_code ~= 0 then
            local detail = diff_stderr ~= '' and diff_stderr or 'Could not load diff.'
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, split_lines(detail))
            return
          end
          if vim.tbl_isempty(diff_lines) then
            diff_lines = { 'No diff for ' .. path }
          end
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, diff_lines)
        end)
      end,
    }

    pickers
      .new({}, {
        prompt_title = kind == 'jj' and 'jj: branch changes ' .. range
          or 'git: branch changes vs ' .. base,
        finder = finders.new_table {
          results = entries,
          entry_maker = function(path)
            local entry = file_entry_maker(path)
            entry.value = path
            return entry
          end,
        },
        previewer = diff_previewer,
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if not entry or not entry.value then
              vim.notify('No changed file on this line.', vim.log.levels.INFO)
              return
            end
            local path = root .. '/' .. entry.value
            if vim.uv.fs_stat(path) then
              vim.cmd.edit(vim.fn.fnameescape(path))
            else
              vim.notify('Changed file no longer exists: ' .. entry.value, vim.log.levels.INFO)
            end
          end)
          return true
        end,
      })
      :find()
  end)
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
      local jj = require 'jjsigns.jj'
      local orig_get_repo_root = jj.get_repo_root
      jj.get_repo_root = function(path)
        local root = orig_get_repo_root(path)
        if not (root and path) then
          return root
        end

        local real_root = vim.uv.fs_realpath(root)
        local real_path = vim.uv.fs_realpath(path)
        if not (real_root and real_path and vim.startswith(real_path, real_root)) then
          return root
        end

        -- `jj root` may return a canonical path while the buffer was opened via
        -- a symlink. jjsigns slices buffer paths by repo root, so keep the root
        -- in the same spelling as the buffer path when they resolve together.
        local suffix = real_path:sub(#real_root + 2)
        if suffix == '' then
          return vim.fs.normalize(path)
        end

        return vim.fs.normalize(path:sub(1, #path - #suffix - 1))
      end

      local function toggle_jj_signs_base()
        local bufname = vim.api.nvim_buf_get_name(0)
        local path = bufname ~= '' and vim.fs.normalize(bufname) or vim.fn.getcwd(0)
        local root = vcs.find_root(path)
        if not root or not vim.uv.fs_stat(root .. '/.jj') then
          vim.notify('Not inside a jj repository.', vim.log.levels.WARN)
          return
        end

        local config = require 'jjsigns.config'
        if config.config.base ~= '@-' then
          config.config.base = '@-'
          require('jjsigns.attach').refresh_all()
          vim.notify('jjsigns base: @-')
          return
        end

        local base = find_jj_default_branch(root)
        if not base then
          vim.notify('Could not find default branch. Set vim.g.dot_vcs_default_branches.', vim.log.levels.WARN)
          return
        end

        config.config.base = base
        require('jjsigns.attach').refresh_all()
        vim.notify('jjsigns base: ' .. base)
      end

      local function map_jj_change_navigation(bufnr)
        if vcs.workspace_kind(bufnr) ~= 'jj' then
          return
        end

        local function jump_to_jj_change(direction)
          if vim.wo.diff then
            vim.cmd.normal { direction == 'next' and ']c' or '[c', bang = true }
            return
          end

          local signs = require('jjsigns.signs').get_buffer_signs(bufnr) or {}
          if vim.tbl_isempty(signs) then
            vim.notify('No jj changes in this buffer.', vim.log.levels.INFO)
            return
          end

          table.sort(signs, function(a, b)
            return a.line < b.line
          end)

          local current = vim.api.nvim_win_get_cursor(0)[1]
          local target = direction == 'next' and signs[1].line or signs[#signs].line
          if direction == 'next' then
            for _, sign in ipairs(signs) do
              if sign.line > current then
                target = sign.line
                break
              end
            end
          else
            for i = #signs, 1, -1 do
              if signs[i].line < current then
                target = signs[i].line
                break
              end
            end
          end

          vim.api.nvim_win_set_cursor(0, { target, 0 })
        end

        vim.keymap.set('n', ']c', function()
          jump_to_jj_change 'next'
        end, { buffer = bufnr, desc = 'jj: next change' })
        vim.keymap.set('n', '[c', function()
          jump_to_jj_change 'prev'
        end, { buffer = bufnr, desc = 'jj: previous change' })
      end

      local attach = require 'jjsigns.attach'
      local orig_attach_to_buffer = attach.attach_to_buffer
      if orig_attach_to_buffer then
        attach.attach_to_buffer = function(bufnr)
          local filepath = vim.api.nvim_buf_get_name(bufnr)
          if filepath:match '^jar://' then
            return
          end
          orig_attach_to_buffer(bufnr)
          if attach.is_attached(bufnr) then
            map_jj_change_navigation(bufnr)
          end
        end
      end

      require('jjsigns').setup {
        base = '@-',
        signs = {
          add = { text = '+' },
          change = { text = '~' },
          delete = { text = '_' },
          topdelete = { text = '‾' },
          changedelete = { text = '~' },
        },
      }

      vim.defer_fn(function()
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(bufnr) then
            map_jj_change_navigation(bufnr)
          end
        end
      end, 100)

      vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        group = vim.api.nvim_create_augroup('dot-jjsigns-skip-jar', { clear = true }),
        callback = function(args)
          local filepath = vim.api.nvim_buf_get_name(args.buf)
          if filepath:match '^jar://' then
            pcall(require('jjsigns.attach').detach_buffer, args.buf)
          else
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(args.buf) then
                map_jj_change_navigation(args.buf)
              end
            end, 100)
          end
        end,
      })

      vim.keymap.set('n', '<leader>tJ', toggle_jj_signs_base, { desc = 'Toggle jj signs base' })
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
      { '<leader>gj', open_jj_status, desc = 'jj: status' },
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
        '<leader>gb',
        open_branch_changes,
        desc = 'VCS: branch changes',
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
