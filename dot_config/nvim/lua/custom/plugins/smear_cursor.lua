-- Animated cursor smear drawn with Unicode block characters, so it works in
-- terminals without cursor shaders (Windows Terminal / WSL). Skipped under
-- Ghostty, whose custom-shader already animates the cursor.
local function is_ghostty(term) return (term or ''):lower():find('ghostty', 1, true) ~= nil end

local function running_in_ghostty()
  -- Inside tmux, TERM/TERM_PROGRAM describe tmux and Ghostty's env vars are
  -- whatever the server's first client had, so ask about the attached client.
  if vim.env.TMUX ~= nil then
    if vim.fn.executable 'tmux' ~= 1 then return false end
    return vim.iter(vim.fn.systemlist { 'tmux', 'display-message', '-p', '#{client_termname}' }):any(is_ghostty)
  end
  -- TERM=xterm-ghostty also survives ssh, where TERM_PROGRAM does not.
  return is_ghostty(vim.env.TERM_PROGRAM) or is_ghostty(vim.env.TERM)
end

return {
  {
    'sphamba/smear-cursor.nvim',
    event = 'VeryLazy',
    cond = function() return not running_in_ghostty() end,
    opts = {},
  },
}
