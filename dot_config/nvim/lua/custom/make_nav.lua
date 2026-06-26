local M = {}

local function is_target_line(line)
  if line:match '^%s*$' or line:match '^%s*#' or line:match '^\t' then return false end
  return not line:match '^%s*[%w_.%-]+%s*[:+?!]?='
end

local function parse_target_line(line)
  if not is_target_line(line) then return nil end

  local target_text = line:match '^%s*([^:#=]+)::?[^=]?.*$'
  if not target_text then return nil end

  local targets = {}
  for target in target_text:gmatch '%S+' do
    if not target:match '^#' then targets[#targets + 1] = target:gsub('\\$', '') end
  end

  return #targets > 0 and targets or nil
end

local function make_targets(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local targets = {}

  for i, line in ipairs(lines) do
    local parsed = parse_target_line(line)
    if parsed then
      for _, target in ipairs(parsed) do
        targets[#targets + 1] = {
          target = target,
          line = i,
          text = line,
        }
      end
    end
  end

  return targets
end

local function jump_to_target(item)
  vim.api.nvim_win_set_cursor(0, { item.line, 0 })
  vim.cmd 'normal! zv'
end

local function word_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local start_col = col
  local end_col = col

  while start_col > 1 and line:sub(start_col - 1, start_col - 1):match '[%w_./%-]' do
    start_col = start_col - 1
  end

  while end_col <= #line and line:sub(end_col, end_col):match '[%w_./%-]' do
    end_col = end_col + 1
  end

  local word = line:sub(start_col, end_col - 1)
  return word ~= '' and word or nil
end

function M.goto_target()
  local target_name = word_at_cursor()
  if not target_name then return M.outline() end

  for _, item in ipairs(make_targets()) do
    if item.target == target_name then
      jump_to_target(item)
      return
    end
  end

  vim.notify(string.format('[make] No target found for %q', target_name), vim.log.levels.INFO)
end

function M.outline()
  local ok, pickers = pcall(require, 'telescope.pickers')
  if not ok then
    vim.notify('[make] Telescope is unavailable', vim.log.levels.WARN)
    return
  end

  local targets = make_targets()
  if #targets == 0 then
    vim.notify('[make] No targets found', vim.log.levels.INFO)
    return
  end

  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  pickers
    .new({}, {
      prompt_title = 'Make targets',
      finder = finders.new_table {
        results = targets,
        entry_maker = function(item)
          return {
            value = item,
            ordinal = item.target .. ' ' .. item.text,
            display = string.format('%-30s %4d  %s', item.target, item.line, item.text),
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local item = action_state.get_selected_entry().value
          actions.close(prompt_bufnr)
          jump_to_target(item)
        end)
        return true
      end,
    })
    :find()
end

return M
