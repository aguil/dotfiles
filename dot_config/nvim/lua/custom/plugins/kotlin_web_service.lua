return {
  {
    'folke/which-key.nvim',
    optional = true,
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>k', group = '[K]otlin/Gradle' })
    end,
  },
  {
    'nvim-lua/plenary.nvim',
    lazy = false,
    config = function()
      local uv = vim.uv or vim.loop

      local function detect_project_root()
        local cwd = vim.fn.getcwd()
        local git_root = vim.fs.root(cwd, '.git')
        return git_root or cwd
      end

      local function gradle_bin(root)
        local wrapper = root .. '/gradlew'
        if uv.fs_stat(wrapper) then
          return './gradlew'
        end
        return 'gradle'
      end

      local function run_gradle(task_args)
        local root = detect_project_root()
        local gradle = gradle_bin(root)

        if gradle == 'gradle' and vim.fn.executable('gradle') ~= 1 then
          vim.notify('[kotlin] gradle executable not found (wrapper and global gradle are both missing)', vim.log.levels.ERROR)
          return
        end

        vim.cmd 'botright 14split'
        vim.fn.termopen(gradle .. ' ' .. task_args, { cwd = root })
        vim.cmd 'startinsert'
      end

      local function show_kotlin_keys()
        local lines = {
          '# Kotlin/Neovim navigation quick reference',
          '',
          '## Core navigation',
          '- Window movement: Ctrl-h / Ctrl-j / Ctrl-k / Ctrl-l',
          '- Go to definition: grd',
          '- Go to declaration: grD',
          '- Find references: grr',
          '- Go to implementation: gri',
          '- Go to type definition: grt',
          '- Rename symbol: grn',
          '- Code action: gra',
          '- Document symbols: gO',
          '- Workspace symbols: gW',
          '- Diagnostics list: <leader>q',
          '- Diagnostics picker: <leader>sd',
          '',
          '## Kotlin/Gradle workflow',
          '- Build: <leader>kb (:GradleBuild)',
          '- Test: <leader>kt (:GradleTest)',
          '- Boot run: <leader>kr (:GradleBootRun)',
          '- Custom task: <leader>kk (:Gradle <task>)',
          '',
          'Press q to close this buffer.',
        }

        vim.cmd 'botright new'
        local buf = vim.api.nvim_get_current_buf()
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].swapfile = false
        vim.bo[buf].modifiable = true
        vim.bo[buf].filetype = 'markdown'
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false
        vim.keymap.set('n', 'q', '<cmd>bd!<CR>', { buffer = buf, silent = true })
      end

      vim.api.nvim_create_user_command('Gradle', function(opts)
        run_gradle(table.concat(opts.fargs, ' '))
      end, { nargs = '+' })

      vim.api.nvim_create_user_command('GradleBuild', function()
        run_gradle('build')
      end, {})

      vim.api.nvim_create_user_command('GradleTest', function()
        run_gradle('test')
      end, {})

      vim.api.nvim_create_user_command('GradleBootRun', function()
        run_gradle('bootRun')
      end, {})

      vim.api.nvim_create_user_command('KotlinKeys', function()
        show_kotlin_keys()
      end, {})

      vim.keymap.set('n', '<leader>kb', '<cmd>GradleBuild<CR>', { desc = 'Kotlin: gradle build' })
      vim.keymap.set('n', '<leader>kt', '<cmd>GradleTest<CR>', { desc = 'Kotlin: gradle test' })
      vim.keymap.set('n', '<leader>kr', '<cmd>GradleBootRun<CR>', { desc = 'Kotlin: gradle bootRun' })
      vim.keymap.set('n', '<leader>kk', function()
        vim.ui.input({ prompt = 'Gradle task: ' }, function(input)
          if input and input ~= '' then
            run_gradle(input)
          end
        end)
      end, { desc = 'Kotlin: run custom gradle task' })
      vim.keymap.set('n', '<leader>k?', '<cmd>KotlinKeys<CR>', { desc = 'Kotlin: show key reference' })
    end,
  },
}
