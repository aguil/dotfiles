return {
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    opts = {
      direction = 'float',
      float_opts = { border = 'rounded' },
      size = 20,
      close_on_exit = false,
    },
    config = function(_, opts)
      require('toggleterm').setup(opts)

      local Terminal = require('toggleterm.terminal').Terminal
      local ai_term_cmd = vim.env.AI_TERM_CMD or 'agent'
      local max_context_lines = tonumber(vim.env.AI_CONTEXT_LINES or '7') or 7
      local max_file_lines = tonumber(vim.env.AI_FILE_LINES or '300') or 300
      local max_diff_lines = tonumber(vim.env.AI_DIFF_LINES or '300') or 300

      local ai = Terminal:new({
        cmd = ai_term_cmd,
        hidden = true,
        close_on_exit = false,
        direction = 'float',
        on_open = function()
          vim.cmd('startinsert')
        end,
      })

      local command_checked = false

      local function notify(message, level)
        vim.notify('[ai-cli] ' .. message, level or vim.log.levels.INFO)
      end

      local function get_command_binary(command)
        return command:match('^%s*([^%s]+)') or command
      end

      local function command_exists(command)
        local binary = get_command_binary(command)
        return vim.fn.executable(binary) == 1, binary
      end

      local function ensure_open()
        if not command_checked then
          local is_available, binary = command_exists(ai_term_cmd)
          if not is_available then
            notify('command not found in PATH: ' .. binary, vim.log.levels.ERROR)
            return false
          end
          command_checked = true
        end

        if not ai:is_open() then
          ai:open()
        end

        return true
      end

      local function send_text(text)
        if not text or text == '' then
          notify('nothing to send', vim.log.levels.WARN)
          return
        end

        if not ensure_open() then
          return
        end

        ai:send(text, false)
        ai:send('\n', false)
      end

      local function get_visual_selection()
        local start_pos = vim.fn.getpos("'<")
        local end_pos = vim.fn.getpos("'>")
        local srow, scol = start_pos[2] - 1, start_pos[3] - 1
        local erow, ecol = end_pos[2] - 1, end_pos[3] - 1

        if srow > erow or (srow == erow and scol > ecol) then
          srow, erow = erow, srow
          scol, ecol = ecol, scol
        end

        local mode = vim.fn.visualmode()
        local start_line = vim.api.nvim_buf_get_lines(0, srow, srow + 1, false)[1] or ''
        local end_line = vim.api.nvim_buf_get_lines(0, erow, erow + 1, false)[1] or ''

        scol = math.max(0, math.min(scol, #start_line))
        if mode == 'V' then
          scol = 0
          ecol = #end_line
        else
          ecol = math.min(ecol + 1, #end_line)
        end

        if srow == erow and scol > ecol then
          scol, ecol = ecol, scol
        end

        local lines = vim.api.nvim_buf_get_text(0, srow, scol, erow, ecol, {})
        return table.concat(lines, '\n')
      end

      local function shell_join(args)
        local escaped = {}
        for _, value in ipairs(args) do
          table.insert(escaped, vim.fn.shellescape(value))
        end
        return table.concat(escaped, ' ')
      end

      local function run_system(args, cwd)
        if vim.system then
          local result = vim.system(args, { cwd = cwd, text = true }):wait()
          if result.code == 0 then
            return result.stdout or ''
          end

          local stderr = result.stderr and result.stderr:gsub('%s+$', '') or ''
          if stderr == '' then
            stderr = 'exit code ' .. tostring(result.code)
          end
          return nil, stderr
        end

        local cmd = shell_join(args)
        if cwd and cwd ~= '' then
          cmd = 'cd ' .. vim.fn.shellescape(cwd) .. ' && ' .. cmd
        end

        local output = vim.fn.system(cmd)
        if vim.v.shell_error == 0 then
          return output
        end

        return nil, output:gsub('%s+$', '')
      end

      local function trim_lines(lines, max_lines)
        if #lines <= max_lines then
          return lines
        end

        local trimmed = {}
        for i = 1, max_lines do
          trimmed[i] = lines[i]
        end
        table.insert(trimmed, '')
        table.insert(trimmed, string.format('[truncated: showing first %d of %d lines]', max_lines, #lines))
        return trimmed
      end

      local function with_line_numbers(lines, start_line)
        local numbered = {}
        for i, text in ipairs(lines) do
          table.insert(numbered, string.format('%d: %s', start_line + i - 1, text))
        end
        return numbered
      end

      local function split_lines(text)
        if not text or text == '' then
          return {}
        end
        return vim.split(text, '\n', { plain = true })
      end

      local function current_file_path()
        local file = vim.fn.expand('%:p')
        if file == '' then
          return nil
        end
        return file
      end

      local function get_git_root(path)
        local output = run_system({ 'git', '-C', path, 'rev-parse', '--show-toplevel' })
        if not output then
          return nil
        end
        return output:gsub('%s+$', '')
      end

      local function rel_to_root(file, root)
        local prefix = root .. '/'
        if file:sub(1, #prefix) == prefix then
          return file:sub(#prefix + 1)
        end
        return vim.fn.fnamemodify(file, ':t')
      end

      local function format_diagnostics()
        local diags = vim.diagnostic.get(0)
        if #diags == 0 then
          return 'none'
        end

        local out = {}
        local max_items = math.min(#diags, 10)
        for i = 1, max_items do
          local d = diags[i]
          local severity = ({
            [vim.diagnostic.severity.ERROR] = 'ERROR',
            [vim.diagnostic.severity.WARN] = 'WARN',
            [vim.diagnostic.severity.INFO] = 'INFO',
            [vim.diagnostic.severity.HINT] = 'HINT',
          })[d.severity] or 'UNKNOWN'
          table.insert(out, string.format('- %s L%d:C%d %s', severity, d.lnum + 1, d.col + 1, d.message:gsub('\n', ' ')))
        end

        if #diags > max_items then
          table.insert(out, string.format('- ... %d more diagnostics', #diags - max_items))
        end

        return table.concat(out, '\n')
      end

      local function build_here_prompt(extra_prompt, selected_text)
        local file = current_file_path() or '[No file]'
        local line = vim.fn.line('.')
        local col = vim.fn.col('.')
        local radius = math.max(1, math.floor(max_context_lines / 2))
        local start_line = math.max(1, line - radius)
        local end_line = line + radius
        local context_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
        local numbered = with_line_numbers(context_lines, start_line)

        local parts = {
          'Please help with this Neovim code context.',
          '',
          string.format('File: %s', file),
          string.format('Cursor: line %d, col %d', line, col),
          '',
          'Diagnostics:',
          format_diagnostics(),
          '',
          'Nearby code:',
          table.concat(numbered, '\n'),
        }

        if selected_text and selected_text ~= '' then
          table.insert(parts, '')
          table.insert(parts, 'Selected text:')
          table.insert(parts, selected_text)
        end

        if extra_prompt and extra_prompt ~= '' then
          table.insert(parts, '')
          table.insert(parts, 'Request:')
          table.insert(parts, extra_prompt)
        end

        return table.concat(parts, '\n')
      end

      local function build_file_prompt(extra_prompt)
        local file = current_file_path()
        if not file then
          return nil, 'no file is active in this buffer'
        end

        local all_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local numbered_lines = with_line_numbers(trim_lines(all_lines, max_file_lines), 1)

        local parts = {
          'Please review this file context.',
          '',
          string.format('File: %s', file),
          '',
          'Diagnostics:',
          format_diagnostics(),
          '',
          'File content:',
          table.concat(numbered_lines, '\n'),
        }

        if extra_prompt and extra_prompt ~= '' then
          table.insert(parts, '')
          table.insert(parts, 'Request:')
          table.insert(parts, extra_prompt)
        end

        return table.concat(parts, '\n')
      end

      local function build_diag_prompt(extra_prompt)
        local file = current_file_path() or '[No file]'
        local parts = {
          'Please help triage diagnostics in this file.',
          '',
          string.format('File: %s', file),
          '',
          'Diagnostics:',
          format_diagnostics(),
        }

        if extra_prompt and extra_prompt ~= '' then
          table.insert(parts, '')
          table.insert(parts, 'Request:')
          table.insert(parts, extra_prompt)
        end

        return table.concat(parts, '\n')
      end

      local function build_diff_prompt(staged, extra_prompt)
        local file = current_file_path()
        if not file then
          return nil, 'no file is active in this buffer'
        end

        local dir = vim.fn.fnamemodify(file, ':h')
        local root = get_git_root(dir)
        if not root then
          return nil, 'current file is not inside a git repository'
        end

        local rel_file = rel_to_root(file, root)
        local args = { 'git', '-C', root, 'diff', '--no-ext-diff' }
        if staged then
          table.insert(args, '--staged')
        end
        table.insert(args, '--')
        table.insert(args, rel_file)

        local diff_output, diff_error = run_system(args)
        if not diff_output then
          return nil, 'unable to load git diff: ' .. diff_error
        end

        if diff_output:gsub('%s+', '') == '' then
          if staged then
            return nil, 'no staged changes for current file'
          end
          return nil, 'no unstaged changes for current file'
        end

        local diff_lines = trim_lines(split_lines(diff_output), max_diff_lines)
        local scope = staged and 'staged' or 'working tree'
        local parts = {
          string.format('Please review this %s git diff.', scope),
          '',
          string.format('Repository: %s', root),
          string.format('File: %s', rel_file),
          '',
          'Diff:',
          table.concat(diff_lines, '\n'),
        }

        if extra_prompt and extra_prompt ~= '' then
          table.insert(parts, '')
          table.insert(parts, 'Request:')
          table.insert(parts, extra_prompt)
        end

        return table.concat(parts, '\n')
      end

      local function send_or_warn(prompt_builder, ...)
        local prompt, error_message = prompt_builder(...)
        if not prompt then
          notify(error_message, vim.log.levels.WARN)
          return
        end
        send_text(prompt)
      end

      local function show_status()
        local is_available, binary = command_exists(ai_term_cmd)
        local state = ai:is_open() and 'open' or 'closed'
        local command_status = is_available and 'available' or 'missing'
        local level = is_available and vim.log.levels.INFO or vim.log.levels.ERROR
        notify(string.format('cmd="%s" (%s), terminal=%s', ai_term_cmd, command_status, state), level)
        if not is_available then
          notify('install or add to PATH: ' .. binary, vim.log.levels.WARN)
        end
      end

      vim.keymap.set('n', '<leader>at', function()
        ai:toggle()
      end, { desc = 'AI: toggle terminal' })

      vim.keymap.set('n', '<leader>al', function()
        send_text(vim.api.nvim_get_current_line())
      end, { desc = 'AI: send current line' })

      vim.keymap.set('v', '<leader>as', function()
        send_text(get_visual_selection())
      end, { desc = 'AI: send selection' })

      vim.keymap.set('n', '<leader>ah', function()
        send_or_warn(build_here_prompt, '', nil)
      end, { desc = 'AI: send file+diag context' })

      vim.keymap.set('v', '<leader>ah', function()
        send_or_warn(build_here_prompt, '', get_visual_selection())
      end, { desc = 'AI: send context + selection' })

      vim.keymap.set('n', '<leader>af', function()
        send_or_warn(build_file_prompt, '')
      end, { desc = 'AI: send current file' })

      vim.keymap.set('n', '<leader>ad', function()
        send_or_warn(build_diff_prompt, false, '')
      end, { desc = 'AI: send git diff (file)' })

      vim.keymap.set('n', '<leader>aD', function()
        send_or_warn(build_diff_prompt, true, '')
      end, { desc = 'AI: send staged diff (file)' })

      vim.keymap.set('n', '<leader>ax', function()
        send_text(build_diag_prompt(''))
      end, { desc = 'AI: send diagnostics' })

      vim.keymap.set('n', '<leader>ai', function()
        show_status()
      end, { desc = 'AI: status' })

      vim.api.nvim_create_user_command('AiSend', function(command_opts)
        send_text(command_opts.args)
      end, { nargs = '+' })

      vim.api.nvim_create_user_command('AiHere', function(command_opts)
        send_or_warn(build_here_prompt, command_opts.args, nil)
      end, { nargs = '*' })

      vim.api.nvim_create_user_command('AiFile', function(command_opts)
        send_or_warn(build_file_prompt, command_opts.args)
      end, { nargs = '*' })

      vim.api.nvim_create_user_command('AiDiag', function(command_opts)
        send_text(build_diag_prompt(command_opts.args))
      end, { nargs = '*' })

      vim.api.nvim_create_user_command('AiDiff', function(command_opts)
        send_or_warn(build_diff_prompt, false, command_opts.args)
      end, { nargs = '*' })

      vim.api.nvim_create_user_command('AiDiffStaged', function(command_opts)
        send_or_warn(build_diff_prompt, true, command_opts.args)
      end, { nargs = '*' })

      vim.api.nvim_create_user_command('AiStatus', function()
        show_status()
      end, { nargs = 0 })
    end,
  },
}
