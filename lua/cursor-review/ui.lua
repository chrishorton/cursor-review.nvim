-- cursor-review.nvim UI module
-- Floating dialogs for commit messages using nui.nvim

local M = {}
local git = require("cursor-review.git")

--- Get count of staged files
---@return number Number of staged files
function M.get_staged_count()
  local result = vim.fn.systemlist(git.cmd("diff --cached --name-only 2>/dev/null"))
  if vim.v.shell_error ~= 0 then
    return 0
  end
  return #result
end

--- Get list of staged file names
---@return string[] List of staged file paths
function M.get_staged_files()
  local result = vim.fn.systemlist(git.cmd("diff --cached --name-only 2>/dev/null"))
  if vim.v.shell_error ~= 0 then
    return {}
  end
  return result
end

--- Get the last commit message
---@return string|nil Last commit message or nil if error
function M.get_last_commit_message()
  local result = vim.fn.system(git.cmd("log -1 --format=%s 2>/dev/null"))
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result:gsub("\n", "")
end

--- Check if we're in a git repository (checks both real and alternate)
---@return boolean
function M.is_git_repo()
  vim.fn.system(git.cmd("rev-parse --git-dir 2>/dev/null"))
  if vim.v.shell_error == 0 then
    return true
  end
  -- Fallback: check real .git
  vim.fn.system("git rev-parse --git-dir 2>/dev/null")
  return vim.v.shell_error == 0
end

--- Get current git status (porcelain)
---@return string Git status output
function M.get_git_status()
  return vim.fn.system(git.cmd("status --porcelain 2>/dev/null"))
end

--- Show floating input dialog for commit/amend
---@param config table Plugin configuration
---@param opts table Options: { amend = bool, default_message = string }
function M.show_commit_dialog(config, opts)
  opts = opts or {}

  -- Check for nui.nvim
  local ok_input, Input = pcall(require, "nui.input")
  local ok_event, nui_event = pcall(require, "nui.utils.autocmd")
  if not ok_input or not ok_event then
    vim.notify("cursor-review: nui.nvim is required for floating dialogs", vim.log.levels.ERROR)
    return
  end
  local event = nui_event.event

  local staged_count = M.get_staged_count()

  if staged_count == 0 then
    vim.notify(
      "No staged changes to commit. Use " .. config.keymaps.stage_hunk .. " to stage hunks.",
      vim.log.levels.WARN
    )
    return
  end

  -- Build title
  local title = opts.amend and config.ui.amend_title or config.ui.commit_title
  title = string.format("%s(%d file%s staged) ", title, staged_count, staged_count == 1 and "" or "s")

  local input = Input({
    position = "50%",
    size = {
      width = config.ui.width,
    },
    border = {
      style = config.ui.border,
      padding = { 0, 1 },
      text = {
        top = title,
        top_align = "center",
        bottom = " <Enter> confirm | <Esc> cancel ",
        bottom_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  }, {
    prompt = "> ",
    default_value = opts.default_message or "",
    on_submit = function(value)
      if value and value ~= "" then
        local escaped_msg = value:gsub('"', '\\"')
        local cmd = opts.amend
          and git.cmd(string.format('commit --amend -m "%s"', escaped_msg))
          or git.cmd(string.format('commit -m "%s"', escaped_msg))

        local result = vim.fn.system(cmd)

        if vim.v.shell_error == 0 then
          local action = opts.amend and "Amended" or "Committed"
          if config.notifications.enable then
            vim.notify(action .. ": " .. value, vim.log.levels.INFO)
          end
          -- Refresh gitsigns if available
          pcall(vim.cmd, "Gitsigns refresh")
        else
          vim.notify("Commit failed: " .. result, vim.log.levels.ERROR)
        end
      else
        if config.notifications.enable then
          vim.notify("Commit cancelled (empty message)", vim.log.levels.WARN)
        end
      end
    end,
  })

  input:mount()

  -- Close handlers
  local function close_dialog()
    input:unmount()
    if config.notifications.enable then
      vim.notify("Commit cancelled", vim.log.levels.INFO)
    end
  end

  input:map("n", "<Esc>", close_dialog, { noremap = true })
  input:map("i", "<Esc>", close_dialog, { noremap = true })

  -- Auto-close when buffer is left
  input:on(event.BufLeave, function()
    input:unmount()
  end)

  -- Start in insert mode at end of line
  vim.cmd("startinsert!")
end

--- Show confirmation dialog
---@param message string Confirmation message
---@param on_confirm function Callback if confirmed
---@param on_cancel function|nil Callback if cancelled
function M.confirm(message, on_confirm, on_cancel)
  local choice = vim.fn.confirm(message, "&Yes\n&No", 2)
  if choice == 1 then
    on_confirm()
  elseif on_cancel then
    on_cancel()
  end
end

return M

