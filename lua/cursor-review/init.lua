-- cursor-review.nvim
-- Review Cursor Agent changes in Neovim with hunk-by-hunk accept/reject workflow
--
-- Features:
-- - Checkpoint commits before running Cursor Agent
-- - Diffview integration for reviewing all changes
-- - Gitsigns integration for hunk-level staging/resetting
-- - Floating dialogs for commit messages
-- - Amend support for iterative changes
--
-- Usage:
--   require("cursor-review").setup({
--     -- your config here
--   })
--
-- Commands:
--   :CursorCheckpoint  - Create checkpoint before Cursor
--   :CursorReview      - Open diffview to review changes
--   :CursorFinalize    - Commit staged changes (floating dialog)
--   :CursorAmend       - Amend to previous commit (keep message)
--   :CursorAmend!      - Amend to previous commit (edit message)
--   :CursorAbort       - Discard all unstaged changes

local M = {}

-- Plugin state
M._config = nil
M._initialized = false

--- Get the current configuration
---@return table|nil
function M.get_config()
  return M._config
end

--- Check if plugin is initialized
---@return boolean
function M.is_initialized()
  return M._initialized
end

--- Setup the plugin
---@param opts table|nil User configuration options
function M.setup(opts)
  -- Prevent double initialization
  if M._initialized then
    vim.notify("cursor-review: already initialized", vim.log.levels.WARN)
    return
  end

  -- Merge configuration
  local config_module = require("cursor-review.config")
  M._config = config_module.merge(opts)

  -- Initialize git module with config
  local git = require("cursor-review.git")
  git.init_config(M._config)

  -- Check dependencies
  local deps_ok = true

  if not pcall(require, "gitsigns") then
    vim.notify("cursor-review: gitsigns.nvim is required but not found", vim.log.levels.ERROR)
    deps_ok = false
  end

  if not pcall(require, "diffview") then
    vim.notify("cursor-review: diffview.nvim is required but not found", vim.log.levels.ERROR)
    deps_ok = false
  end

  if not pcall(require, "nui.input") then
    vim.notify("cursor-review: nui.nvim is required but not found", vim.log.levels.ERROR)
    deps_ok = false
  end

  if not deps_ok then
    vim.notify("cursor-review: missing dependencies, some features may not work", vim.log.levels.WARN)
  end

  -- Setup gitsigns with our keymaps
  local gitsigns_ok, gitsigns_module = pcall(require, "cursor-review.gitsigns")
  if gitsigns_ok then
    gitsigns_module.setup(M._config)
  end

  -- Setup diffview with our keymaps
  local diffview_ok, diffview_module = pcall(require, "cursor-review.diffview")
  if diffview_ok then
    diffview_module.setup(M._config)
  end

  -- Register commands
  local commands_module = require("cursor-review.commands")
  commands_module.setup(M._config)

  -- Setup global keymaps if enabled
  if M._config.keymaps.enable then
    commands_module.setup_keymaps(M._config)
  end

  M._initialized = true

  if M._config.notifications.enable then
    vim.notify("cursor-review: initialized", vim.log.levels.INFO)
  end
end

--- Manually trigger checkpoint
---@param message string|nil Optional commit message
function M.checkpoint(message)
  if not M._initialized then
    vim.notify("cursor-review: not initialized, call setup() first", vim.log.levels.ERROR)
    return
  end
  vim.cmd((M._config.commands.checkpoint or "CursorCheckpoint") .. " " .. (message or ""))
end

--- Manually open review
function M.review()
  if not M._initialized then
    vim.notify("cursor-review: not initialized, call setup() first", vim.log.levels.ERROR)
    return
  end
  vim.cmd(M._config.commands.review or "CursorReview")
end

--- Manually finalize (commit)
function M.finalize()
  if not M._initialized then
    vim.notify("cursor-review: not initialized, call setup() first", vim.log.levels.ERROR)
    return
  end
  vim.cmd(M._config.commands.finalize or "CursorFinalize")
end

--- Manually amend
---@param edit_message boolean|nil Whether to edit the message (default: false)
function M.amend(edit_message)
  if not M._initialized then
    vim.notify("cursor-review: not initialized, call setup() first", vim.log.levels.ERROR)
    return
  end
  local cmd = M._config.commands.amend or "CursorAmend"
  if edit_message then
    cmd = cmd .. "!"
  end
  vim.cmd(cmd)
end

--- Manually abort (discard unstaged)
function M.abort()
  if not M._initialized then
    vim.notify("cursor-review: not initialized, call setup() first", vim.log.levels.ERROR)
    return
  end
  vim.cmd(M._config.commands.abort or "CursorAbort")
end

return M

