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

      local ai = Terminal:new({
        cmd = ai_term_cmd,
        hidden = true,
        close_on_exit = false,
        direction = 'float',
        on_open = function()
          vim.cmd('startinsert')
        end,
      })

      local function ensure_open()
        if not ai:is_open() then
          ai:open()
        end
      end

      local function send_text(text)
        if not text or text == '' then
          return
        end

        ensure_open()
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
        local file = vim.fn.expand('%:p')
        local line = vim.fn.line('.')
        local col = vim.fn.col('.')
        local start_line = math.max(1, line - 3)
        local end_line = line + 3
        local context_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

        local numbered = {}
        for i, text in ipairs(context_lines) do
          table.insert(numbered, string.format('%d: %s', start_line + i - 1, text))
        end

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
        send_text(build_here_prompt('', nil))
      end, { desc = 'AI: send file+diag context' })

      vim.keymap.set('v', '<leader>ah', function()
        send_text(build_here_prompt('', get_visual_selection()))
      end, { desc = 'AI: send context + selection' })

      vim.api.nvim_create_user_command('AiSend', function(command_opts)
        send_text(command_opts.args)
      end, { nargs = '+' })

      vim.api.nvim_create_user_command('AiHere', function(command_opts)
        send_text(build_here_prompt(command_opts.args, nil))
      end, { nargs = '*' })
    end,
  },
}
