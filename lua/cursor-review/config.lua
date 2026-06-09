-- cursor-review.nvim configuration
-- Default options and configuration merging

local M = {}

M.defaults = {
  -- Alternate git directory for checkpoint isolation.
  -- When set, all checkpoint/review operations use this dir instead of .git,
  -- preventing Cursor's auto-checkpoint from interfering with your staging area.
  -- Set to nil to use the normal .git directory (original behavior).
  git_dir = nil, -- e.g., ".cursor-git"

  -- Keymap configuration
  keymaps = {
    enable = true,

    -- Workflow commands
    checkpoint = "<leader>cp",
    review = "<leader>cr",
    finalize = "<leader>cf",
    amend = "<leader>cm",
    amend_edit = "<leader>cM",
    abort = "<leader>ca",

    -- Diffview shortcuts
    diffview_open = "<leader>dv",
    diffview_close = "<leader>dc",
    diffview_history = "<leader>dh",

    -- Gitsigns hunk operations
    next_hunk = "]c",
    prev_hunk = "[c",
    stage_hunk = "<leader>hs",
    reset_hunk = "<leader>hr",
    preview_hunk = "<leader>hp",
    undo_stage = "<leader>hu",
    stage_buffer = "<leader>hS",
    reset_buffer = "<leader>hR",
    blame_line = "<leader>hb",
    toggle_blame = "<leader>tb",
    diff_this = "<leader>hd",
    diff_last = "<leader>hD",
  },

  -- Command names (set to false to disable a command)
  commands = {
    checkpoint = "CursorCheckpoint",
    review = "CursorReview",
    finalize = "CursorFinalize",
    amend = "CursorAmend",
    abort = "CursorAbort",
  },

  -- UI options for floating dialogs
  ui = {
    border = "rounded",
    width = 60,
    commit_title = " Commit ",
    amend_title = " Amend Commit ",
  },

  -- Gitsigns configuration (merged with gitsigns defaults)
  gitsigns = {
    signs = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
    },
    signcolumn = true,
    numhl = false,
    linehl = false,
    word_diff = false,
    watch_gitdir = {
      interval = 1000,
      follow_files = true,
    },
    attach_to_untracked = true,
    current_line_blame = false,
    sign_priority = 6,
    update_debounce = 100,
    max_file_length = 40000,
  },

  -- Diffview configuration (merged with diffview defaults)
  diffview = {
    enhanced_diff_hl = true,
    use_icons = true,
    layout = "diff2_horizontal",
    file_panel_width = 35,
  },

  -- Notification settings
  notifications = {
    enable = true,
    verbose = true,  -- Show detailed help on :CursorReview
  },
}

--- Merge user config with defaults
---@param opts table|nil User configuration
---@return table Merged configuration
function M.merge(opts)
  return vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M

