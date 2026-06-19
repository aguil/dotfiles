local M = {}

local url_schemes = {
  file = true,
  ftp = true,
  ftps = true,
  http = true,
  https = true,
  mailto = true,
}

local function trim(value) return (value or ''):match '^%s*(.-)%s*$' end

local function current_col()
  -- nvim_win_get_cursor() is 0-indexed for the column; string positions are 1-indexed.
  return vim.api.nvim_win_get_cursor(0)[2] + 1
end

local function unescape_markdown(value) return value:gsub('\\([%[%]%(%)\\])', '%1') end

local function url_decode(value)
  return (value:gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end))
end

local function normalize_ref_id(value) return trim(value):lower():gsub('%s+', ' ') end

local function strip_title(destination)
  destination = trim(destination)
  if destination:sub(1, 1) == '<' then
    local closing = destination:find('>', 2, true)
    if closing then return destination:sub(2, closing - 1) end
  end

  return destination:match '^([^%s]+)' or destination
end

local function sanitize_target(target)
  target = unescape_markdown(strip_title(target))
  target = target:gsub('[,.;:]+$', '')
  return url_decode(target)
end

local function sanitize_wiki_target(target)
  target = unescape_markdown(trim(target))
  target = target:gsub('[,.;:]+$', '')
  return url_decode(target)
end

local function target_from_markdown_link(line, col)
  local init = 1
  while init <= #line do
    local start_col, end_col = line:find('%b[]%b()', init)
    if not start_col then break end

    if start_col <= col and col <= end_col then
      local match = line:sub(start_col, end_col)
      local destination = match:match '%]%((.*)%)$'
      if destination and destination ~= '' then return sanitize_target(destination) end
    end

    init = end_col + 1
  end
end

local function markdown_links(line)
  local links = {}
  local init = 1
  while init <= #line do
    local start_col, end_col = line:find('%b[]%b()', init)
    if not start_col then break end

    local match = line:sub(start_col, end_col)
    local label, destination = match:match '^%[([^%]]*)%]%((.*)%)$'
    if destination and destination ~= '' then
      links[#links + 1] = {
        col = start_col,
        label = label ~= '' and label or destination,
        target = sanitize_target(destination),
        type = 'link',
      }
    end

    init = end_col + 1
  end

  return links
end

local function target_from_wiki_link(line, col)
  local init = 1
  while init <= #line do
    local start_col, end_col, body = line:find('%[%[([^%]]+)%]%]', init)
    if not start_col then break end

    if start_col <= col and col <= end_col then
      body = body:match '^[^|]+'
      if body and body ~= '' then return sanitize_wiki_target(body) end
    end

    init = end_col + 1
  end
end

local function wiki_links(line)
  local links = {}
  local init = 1
  while init <= #line do
    local start_col, end_col, body = line:find('%[%[([^%]]+)%]%]', init)
    if not start_col then break end

    local target = body:match '^[^|]+'
    local label = body:match '|(.+)$' or target
    if target and target ~= '' then
      links[#links + 1] = {
        col = start_col,
        label = label,
        target = sanitize_wiki_target(target),
        type = 'wiki',
      }
    end

    init = end_col + 1
  end

  return links
end

local function is_footnote_reference_at_cursor(line, col)
  local init = 1
  while init <= #line do
    local start_col, end_col = line:find('%[%^[^%]]+%]', init)
    if not start_col then break end

    if start_col <= col and col <= end_col then return true end

    init = end_col + 1
  end

  return false
end

local function reference_definitions(bufnr)
  local definitions = {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local id, destination = line:match '^%s*%[([^%]]+)%]:%s*(.+)$'
    if id and destination and not id:match '^%^' then definitions[normalize_ref_id(id)] = sanitize_target(destination) end
  end
  return definitions
end

local function reference_links(line, definitions)
  local links = {}
  if not next(definitions) then return links end

  local init = 1
  while init <= #line do
    local start_col, end_col, label, id = line:find('%[([^%]^][^%]]*)%]%[([^%]]*)%]', init)
    if not start_col then break end

    local target = definitions[normalize_ref_id(id ~= '' and id or label)]
    if target then links[#links + 1] = {
      col = start_col,
      label = label,
      target = target,
      type = 'reference',
    } end

    init = end_col + 1
  end

  return links
end

local function target_from_reference_link(bufnr, line, col)
  if is_footnote_reference_at_cursor(line, col) then return nil end

  local definitions = reference_definitions(bufnr)
  if not next(definitions) then return nil end

  local init = 1
  while init <= #line do
    local start_col, end_col, label, id = line:find('%[([^%]]+)%]%[([^%]]*)%]', init)
    if not start_col then break end

    if start_col <= col and col <= end_col then return definitions[normalize_ref_id(id ~= '' and id or label)] end

    init = end_col + 1
  end

  init = 1
  while init <= #line do
    local start_col, end_col, id = line:find('%[([^%]]+)%]', init)
    if not start_col then break end

    if start_col <= col and col <= end_col and line:sub(end_col + 1, end_col + 1) ~= '(' then return definitions[normalize_ref_id(id)] end

    init = end_col + 1
  end
end

local function target_from_cfile()
  local cfile = trim(vim.fn.expand '<cfile>')
  if cfile == '' then return nil end

  cfile = cfile:gsub('^[<({%[]+', '')
  cfile = cfile:gsub('[>)}%]]+$', '')
  return sanitize_target(cfile)
end

function M.target_under_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_get_current_line()
  local col = current_col()

  if is_footnote_reference_at_cursor(line, col) then return nil end

  return target_from_markdown_link(line, col) or target_from_wiki_link(line, col) or target_from_reference_link(bufnr, line, col) or target_from_cfile()
end

local function has_url_scheme(target)
  local scheme = target:match '^([%a][%w+.-]*):'
  return scheme and url_schemes[scheme:lower()]
end

local function split_anchor(target)
  local path, anchor = target:match '^([^#]*)#(.+)$'
  if path then return path, anchor end
  return target, nil
end

local function heading_text(line)
  local markers, text = line:match '^%s*(#+)%s+(.+)%s*$'
  if not markers then return nil end

  return #markers, trim(text:gsub('%s*#+%s*$', ''))
end

local function note_path_candidates(path)
  if path == '' then return { '' } end

  local candidates = { path }
  if vim.fn.fnamemodify(path, ':e') == '' then candidates[#candidates + 1] = path .. '.md' end
  return candidates
end

local function resolve_path(path, bufnr)
  if path == '' then return vim.api.nvim_buf_get_name(bufnr) end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local base_dir = (bufname ~= '' and vim.fs.dirname(bufname)) or vim.uv.cwd()
  for _, candidate in ipairs(note_path_candidates(path)) do
    local resolved = candidate
    if not vim.startswith(candidate, '/') then resolved = vim.fs.normalize(vim.fs.joinpath(base_dir, candidate)) end
    if vim.fn.filereadable(resolved) == 1 or vim.fn.isdirectory(resolved) == 1 then return resolved end
  end

  local fallback = note_path_candidates(path)[1]
  if vim.startswith(fallback, '/') then return fallback end
  return vim.fs.normalize(vim.fs.joinpath(base_dir, fallback))
end

local function heading_slug(text)
  text = text:gsub('^%s*#+%s*', ''):gsub('%s*#+%s*$', '')
  text = text:lower():gsub('[`*_~%[%]%(%){}:;,.!?\'"]', '')
  text = text:gsub('[^%w%s%-]', ''):gsub('%s+', '-'):gsub('%-+', '-')
  return text:gsub('^%-', ''):gsub('%-$', '')
end

local function jump_to_anchor(anchor)
  if not anchor or anchor == '' then return end

  local wanted = heading_slug(anchor)
  for line_number, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line:match '^%s*#' and (heading_slug(line) == wanted or trim(line:gsub('^%s*#+%s*', '')) == anchor) then
      vim.api.nvim_win_set_cursor(0, { line_number, 0 })
      vim.cmd 'normal! zv'
      return
    end
  end
end

local function try_lsp_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= 'markdown' or #vim.lsp.get_clients { bufnr = bufnr, name = 'markdown_oxide' } == 0 then return false end

  local params = vim.lsp.util.make_position_params(0, 'utf-8')
  local responses = vim.lsp.buf_request_sync(bufnr, 'textDocument/definition', params, 300)
  if not responses then return false end

  for _, response in pairs(responses) do
    local result = response.result
    if result then
      local location = vim.tbl_islist(result) and result[1] or result
      if location then
        vim.lsp.util.jump_to_location(location, 'utf-8', true)
        return true
      end
    end
  end

  return false
end

function M.open_target(target, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not target or target == '' then return false end

  if has_url_scheme(target) and not vim.startswith(target, 'file://') then
    vim.ui.open(target)
    return true
  end

  if vim.startswith(target, 'file://') then target = vim.uri_to_fname(target) end

  local path, anchor = split_anchor(target)
  local resolved = resolve_path(path, bufnr)
  vim.cmd('edit ' .. vim.fn.fnameescape(resolved))
  jump_to_anchor(anchor)
  return true
end

function M.goto_file()
  if try_lsp_definition() then return end

  local target = M.target_under_cursor(0)
  if M.open_target(target, 0) then return end

  vim.cmd 'normal! gf'
end

function M.outline_items(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local definitions = reference_definitions(bufnr)
  local items = {}

  for index, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local level, text = heading_text(line)
    if level and text ~= '' then
      items[#items + 1] = {
        col = 1,
        kind = 'heading',
        level = level,
        line = index,
        text = text,
      }
    end

    for _, link in ipairs(markdown_links(line)) do
      link.line = index
      link.kind = 'link'
      items[#items + 1] = link
    end

    for _, link in ipairs(wiki_links(line)) do
      link.line = index
      link.kind = 'wiki'
      items[#items + 1] = link
    end

    for _, link in ipairs(reference_links(line, definitions)) do
      link.line = index
      link.kind = 'reference'
      items[#items + 1] = link
    end
  end

  return items
end

local function jump_to_outline_item(item)
  vim.api.nvim_win_set_cursor(0, { item.line, math.max(item.col - 1, 0) })
  vim.cmd 'normal! zv'
end

function M.outline()
  local items = M.outline_items(0)
  if #items == 0 then
    vim.notify('No markdown headings or links found', vim.log.levels.INFO)
    return
  end

  local ok, pickers = pcall(require, 'telescope.pickers')
  if not ok then
    vim.ui.select(items, {
      format_item = function(item) return item.text or string.format('%s -> %s', item.label, item.target) end,
      prompt = 'Markdown Outline',
    }, function(item)
      if item then jump_to_outline_item(item) end
    end)
    return
  end

  local finders = require 'telescope.finders'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local conf = require('telescope.config').values

  pickers
    .new({}, {
      prompt_title = 'Markdown Outline',
      finder = finders.new_table {
        results = items,
        entry_maker = function(item)
          local icon = ({ heading = '#', link = '[]', reference = '[ref]', wiki = '[[]]' })[item.kind] or item.kind
          local text = item.text or item.label or item.target
          local suffix = item.target and (' -> ' .. item.target) or ''
          return {
            display = string.format('%s %s%s', icon, text, suffix),
            ordinal = table.concat({ item.kind, text, item.target or '', item.line }, ' '),
            value = item,
            lnum = item.line,
            col = item.col,
          }
        end,
      },
      previewer = conf.qflist_previewer {},
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local item = action_state.get_selected_entry().value
          actions.close(prompt_bufnr)
          jump_to_outline_item(item)
        end)
        return true
      end,
    })
    :find()
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('custom-markdown-nav', { clear = true }),
    pattern = 'markdown',
    callback = function(event)
      vim.keymap.set('n', '<leader>gf', M.goto_file, { buffer = event.buf, desc = 'Markdown: goto file or note link' })
      vim.keymap.set('n', 'gO', M.outline, { buffer = event.buf, desc = 'Markdown: outline headings and links' })
    end,
  })
end

return M
