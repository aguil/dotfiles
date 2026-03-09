return {
  {
    'olimorris/codecompanion.nvim',
    cmd = { 'CodeCompanion', 'CodeCompanionActions', 'CodeCompanionChat' },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    keys = {
      { '<leader>ac', '<cmd>CodeCompanionChat Toggle<CR>', desc = 'AI: toggle CodeCompanion chat' },
      { '<leader>aa', '<cmd>CodeCompanionActions<CR>', mode = { 'n', 'v' }, desc = 'AI: CodeCompanion actions' },
      { '<leader>ap', '<cmd>CodeCompanion<CR>', mode = { 'n', 'v' }, desc = 'AI: CodeCompanion inline prompt' },
    },
    opts = function()
      local agent_cmd = vim.env.CURSOR_AGENT_BIN or 'agent'
      local is_work_profile = vim.env.AI_TERM_CMD == 'agent' or vim.env.CHEZMOI_PROFILE == 'work'
      local default_adapter = vim.env.CODECOMPANION_ADAPTER

      local chat_adapter = vim.env.CODECOMPANION_CHAT_ADAPTER
      if not chat_adapter or chat_adapter == '' then
        if is_work_profile then
          chat_adapter = 'cursor_acp'
        elseif default_adapter and default_adapter ~= '' then
          chat_adapter = default_adapter
        else
          chat_adapter = 'opencode'
        end
      end

      local inline_adapter = vim.env.CODECOMPANION_INLINE_ADAPTER
      if not inline_adapter or inline_adapter == '' then
        if is_work_profile then
          inline_adapter = 'copilot'
        elseif default_adapter and default_adapter ~= '' and default_adapter ~= 'opencode' and default_adapter ~= 'cursor_acp' then
          inline_adapter = default_adapter
        else
          inline_adapter = 'openai'
        end
      end

      return {
        adapters = {
          acp = {
            cursor_acp = function()
              return require('codecompanion.adapters').extend('codex', {
                name = 'cursor_acp',
                formatted_name = 'Cursor ACP',
                commands = {
                  default = { agent_cmd, 'acp' },
                },
                defaults = {
                  auth_method = 'cursor_login',
                  mcpServers = {},
                  timeout = 20000,
                },
                env = {
                  CURSOR_API_KEY = 'CURSOR_API_KEY',
                  CURSOR_AUTH_TOKEN = 'CURSOR_AUTH_TOKEN',
                },
              })
            end,
          },
        },
        interactions = {
          chat = { adapter = chat_adapter },
          inline = { adapter = inline_adapter },
        },
      }
    end,
  },
}
