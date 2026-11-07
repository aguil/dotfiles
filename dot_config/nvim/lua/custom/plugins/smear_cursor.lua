-- Animated cursor smear drawn with Unicode block characters, so it works in
-- terminals without cursor shaders (Windows Terminal / WSL). Skipped under
-- Ghostty, whose custom-shader already animates the cursor.
local function running_in_ghostty() return vim.env.TERM_PROGRAM == 'ghostty' or vim.env.GHOSTTY_RESOURCES_DIR ~= nil end

return {
  {
    'sphamba/smear-cursor.nvim',
    event = 'VeryLazy',
    cond = function() return not running_in_ghostty() end,
    opts = {},
  },
}
