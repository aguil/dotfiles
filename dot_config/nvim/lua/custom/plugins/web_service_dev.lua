return {
  {
    'folke/which-key.nvim',
    optional = true,
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>k', group = '[K]otlin/Gradle' })
      table.insert(opts.spec, { '<leader>d', group = '[D]art/Web' })
    end,
  },
  {
    'nvim-lua/plenary.nvim',
    lazy = false,
    config = function()
      local uv = vim.uv or vim.loop

      local function detect_project_root()
        local cwd = vim.fn.getcwd()
        local root = vim.fs.root(cwd, { 'pubspec.yaml', 'build.gradle.kts', 'build.gradle', '.git' })
        return root or cwd
      end

      local function gradle_bin(root)
        local wrapper = root .. '/gradlew'
        if uv.fs_stat(wrapper) then
          return './gradlew'
        end
        return 'gradle'
      end

      local function open_term(command, root, opts)
        opts = opts or {}
        local return_winid = opts.return_winid
        local should_focus = opts.start_insert ~= false
        local on_exit = opts.on_exit

        vim.cmd 'botright 14new'
        local term_buf = vim.api.nvim_get_current_buf()
        vim.bo[term_buf].bufhidden = 'hide'
        vim.fn.termopen(command, {
          cwd = root,
          on_exit = function(_, code, signal)
            if on_exit then
              on_exit(code, signal)
            end
          end,
        })
        if should_focus then
          vim.cmd 'startinsert'
        end

        if return_winid and vim.fn.win_gotoid(return_winid) == 1 then
          vim.cmd 'stopinsert'
        end
      end

      local function run_gradle(task_args)
        local root = detect_project_root()
        local gradle = gradle_bin(root)

        if gradle == 'gradle' and vim.fn.executable('gradle') ~= 1 then
          vim.notify('[kotlin] gradle executable not found (wrapper and global gradle are both missing)', vim.log.levels.ERROR)
          return
        end

        open_term(gradle .. ' ' .. task_args, root)
      end

      local function run_dart(task_args)
        local root = detect_project_root()
        if vim.fn.executable('dart') ~= 1 then
          vim.notify('[dart] dart executable not found in PATH', vim.log.levels.ERROR)
          return
        end

        open_term('dart ' .. task_args, root)
      end

      local function run_gradle_refresh_sources()
        local root = detect_project_root()
        local return_winid = vim.fn.win_getid()
        local wrapper = root .. '/gradlew'
        local command
        local using_wrapper = false

        if uv.fs_stat(wrapper) then
          using_wrapper = true
          if vim.fn.executable(wrapper) == 1 then
            command = './gradlew --refresh-dependencies'
          elseif vim.fn.executable('bash') == 1 then
            command = 'bash -lc ' .. vim.fn.shellescape('cd ' .. root .. ' && ./gradlew --refresh-dependencies')
          else
            vim.notify('[kotlin] gradlew exists but is not executable and bash is unavailable', vim.log.levels.ERROR)
            return
          end
        else
          local gradle = gradle_bin(root)
          if gradle == 'gradle' and vim.fn.executable('gradle') ~= 1 then
            vim.notify('[kotlin] gradle executable not found (gradlew missing and global gradle unavailable)', vim.log.levels.ERROR)
            return
          end
          command = gradle .. ' --refresh-dependencies'
        end

        if using_wrapper then
          vim.notify('[kotlin] refreshing dependency sources with project wrapper: ./gradlew', vim.log.levels.INFO)
        else
          vim.notify('[kotlin] refreshing dependency sources with system gradle', vim.log.levels.WARN)
        end

        open_term(command, root, {
          return_winid = return_winid,
          start_insert = false,
          on_exit = function(code)
            local level = code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
            local message = code == 0 and '[kotlin] Gradle dependency refresh finished successfully'
              or string.format('[kotlin] Gradle dependency refresh exited with code %d', code)
            vim.schedule(function()
              vim.notify(message, level)
            end)
          end,
        })
        vim.notify('[kotlin] dependency refresh running in terminal panel', vim.log.levels.INFO)
      end

      local function show_dev_keys()
        local lines = {
          '# Kotlin + Dart/Neovim quick reference',
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
          '- Refresh dependency sources: <leader>kR (:GradleRefreshSources)',
          '',
          '## Dart/Web workflow',
          '- Run app: <leader>dr (:DartRun)',
          '- Test: <leader>dt (:DartTest)',
          '- Webdev serve: <leader>ds (:DartWebServe)',
          '- Build runner build: <leader>db (:DartBuildRunner)',
          '- Build runner watch: <leader>dw (:DartWatch)',
          '- Custom dart command: <leader>dd (:Dart <args>)',
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

      vim.api.nvim_create_user_command('GradleRefreshSources', function()
        run_gradle_refresh_sources()
      end, {})

      vim.api.nvim_create_user_command('KotlinKeys', function()
        show_dev_keys()
      end, {})

      vim.api.nvim_create_user_command('Dart', function(opts)
        run_dart(table.concat(opts.fargs, ' '))
      end, { nargs = '+' })

      vim.api.nvim_create_user_command('DartRun', function()
        run_dart('run')
      end, {})

      vim.api.nvim_create_user_command('DartTest', function()
        run_dart('test')
      end, {})

      vim.api.nvim_create_user_command('DartWebServe', function()
        run_dart('run webdev serve --auto=refresh')
      end, {})

      vim.api.nvim_create_user_command('DartBuildRunner', function()
        run_dart('run build_runner build --delete-conflicting-outputs')
      end, {})

      vim.api.nvim_create_user_command('DartWatch', function()
        run_dart('run build_runner watch --delete-conflicting-outputs')
      end, {})

      vim.api.nvim_create_user_command('DartKeys', function()
        show_dev_keys()
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
      vim.keymap.set('n', '<leader>kR', '<cmd>GradleRefreshSources<CR>', { desc = 'Kotlin: refresh gradle sources' })

      vim.keymap.set('n', '<leader>dr', '<cmd>DartRun<CR>', { desc = 'Dart: run' })
      vim.keymap.set('n', '<leader>dt', '<cmd>DartTest<CR>', { desc = 'Dart: test' })
      vim.keymap.set('n', '<leader>ds', '<cmd>DartWebServe<CR>', { desc = 'Dart: webdev serve' })
      vim.keymap.set('n', '<leader>db', '<cmd>DartBuildRunner<CR>', { desc = 'Dart: build_runner build' })
      vim.keymap.set('n', '<leader>dw', '<cmd>DartWatch<CR>', { desc = 'Dart: build_runner watch' })
      vim.keymap.set('n', '<leader>dd', function()
        vim.ui.input({ prompt = 'Dart args: ' }, function(input)
          if input and input ~= '' then
            run_dart(input)
          end
        end)
      end, { desc = 'Dart: run custom args' })
      vim.keymap.set('n', '<leader>d?', '<cmd>DartKeys<CR>', { desc = 'Dart: show key reference' })
    end,
  },
}
