-- cursor-review.nvim git module
-- Manages an alternate git directory for checkpoint isolation

local M = {}

M._git_dir = nil
M._work_tree = nil
M._in_review = false
M._saved_git_dir = nil
M._saved_git_work_tree = nil

--- Initialize the module with config
---@param config table Plugin configuration
function M.init_config(config)
  if not config.git_dir then
    return
  end

  local cwd = vim.fn.getcwd()
  -- Resolve to absolute path
  if vim.fn.fnamemodify(config.git_dir, ":p") == config.git_dir then
    -- Already absolute
    M._git_dir = config.git_dir
  else
    M._git_dir = cwd .. "/" .. config.git_dir
  end
  M._work_tree = cwd
end

--- Check if alternate git dir is configured
---@return boolean
function M.is_enabled()
  return M._git_dir ~= nil
end

--- Check if we're currently in review mode (env vars set)
---@return boolean
function M.in_review()
  return M._in_review
end

--- Build a git command string with alternate dir flags
---@param args string Git arguments (e.g., "add -A", "commit -m 'msg'")
---@return string Full command string
function M.cmd(args)
  if not M._git_dir then
    return "git " .. args
  end
  return string.format(
    "git --git-dir=%s --work-tree=%s %s",
    vim.fn.shellescape(M._git_dir),
    vim.fn.shellescape(M._work_tree),
    args
  )
end

--- Execute a git command using the alternate dir
---@param args string Git arguments
---@return string Output
function M.system(args)
  return vim.fn.system(M.cmd(args))
end

--- Execute a git command and return lines
---@param args string Git arguments
---@return string[] Output lines
function M.systemlist(args)
  return vim.fn.systemlist(M.cmd(args))
end

--- Execute a git command against the REAL .git (bypasses alternate dir)
---@param args string Git arguments
---@return string Output
function M.real_system(args)
  return vim.fn.system("git " .. args)
end

--- Initialize the alternate git repository if it doesn't exist
---@return boolean Success
function M.ensure_initialized()
  if not M._git_dir then
    return true
  end

  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(M._git_dir)
  if stat then
    return true
  end

  local result = M.system("init")
  if vim.v.shell_error ~= 0 then
    vim.notify("cursor-review: failed to init " .. M._git_dir .. ": " .. result, vim.log.levels.ERROR)
    return false
  end

  -- Add exclusions so the alternate dir doesn't track itself
  local exclude_file = M._git_dir .. "/info/exclude"
  local excludes = vim.fn.readfile(exclude_file)
  local dir_basename = vim.fn.fnamemodify(M._git_dir, ":t")
  table.insert(excludes, "/" .. dir_basename)
  table.insert(excludes, "/" .. dir_basename .. "/")
  vim.fn.writefile(excludes, exclude_file)

  return true
end

--- Enter review mode: set GIT_DIR env so gitsigns/diffview use alternate dir
function M.enter_review()
  if not M._git_dir or M._in_review then
    return
  end

  M._saved_git_dir = vim.env.GIT_DIR
  M._saved_git_work_tree = vim.env.GIT_WORK_TREE

  vim.env.GIT_DIR = M._git_dir
  vim.env.GIT_WORK_TREE = M._work_tree
  M._in_review = true

  -- Refresh gitsigns to pick up new git dir
  vim.schedule(function()
    pcall(function()
      require("gitsigns").refresh()
    end)
  end)
end

--- Exit review mode: restore original GIT_DIR env
function M.exit_review()
  if not M._in_review then
    return
  end

  vim.env.GIT_DIR = M._saved_git_dir
  vim.env.GIT_WORK_TREE = M._saved_git_work_tree
  M._saved_git_dir = nil
  M._saved_git_work_tree = nil
  M._in_review = false

  vim.schedule(function()
    pcall(function()
      require("gitsigns").refresh()
    end)
  end)
end

--- Check if the alternate git dir has any commits
---@return boolean
function M.has_commits()
  if not M._git_dir then
    return false
  end
  M.system("rev-parse HEAD 2>/dev/null")
  return vim.v.shell_error == 0
end

--- Get the HEAD commit message from alternate git dir
---@return string|nil
function M.get_checkpoint_message()
  if not M._git_dir then
    return nil
  end
  local result = M.system("log -1 --format=%s 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result:gsub("\n", "")
end

return M
