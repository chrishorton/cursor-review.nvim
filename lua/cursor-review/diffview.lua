-- cursor-review.nvim diffview module
-- Setup diffview with file staging and restore keymaps

local M = {}

--- Setup diffview with cursor-review keybindings
---@param config table Plugin configuration
function M.setup(config)
  local ok, diffview = pcall(require, "diffview")
  if not ok then
    vim.notify("cursor-review: diffview.nvim is required", vim.log.levels.ERROR)
    return
  end

  local actions = require("diffview.actions")
  local dv_config = config.diffview
  local git = require("cursor-review.git")

  diffview.setup({
    diff_binaries = false,
    enhanced_diff_hl = dv_config.enhanced_diff_hl,
    use_icons = dv_config.use_icons,
    icons = {
      folder_closed = "",
      folder_open = "",
    },
    signs = {
      fold_closed = "",
      fold_open = "",
      done = "✓",
    },
    view = {
      default = {
        layout = dv_config.layout,
        winbar_info = false,
      },
      merge_tool = {
        layout = "diff3_horizontal",
        disable_diagnostics = true,
        winbar_info = true,
      },
      file_history = {
        layout = dv_config.layout,
        winbar_info = false,
      },
    },
    file_panel = {
      listing_style = "tree",
      tree_options = {
        flatten_dirs = true,
        folder_statuses = "only_folded",
      },
      win_config = {
        position = "left",
        width = dv_config.file_panel_width,
      },
    },
    file_history_panel = {
      log_options = {
        git = {
          single_file = {
            diff_merges = "combined",
          },
          multi_file = {
            diff_merges = "first-parent",
          },
        },
      },
      win_config = {
        position = "bottom",
        height = 16,
      },
    },
    commit_log_panel = {
      win_config = {},
    },
    default_args = {
      DiffviewOpen = {},
      DiffviewFileHistory = {},
    },
    hooks = {
      view_closed = function()
        if git.in_review() then
          git.exit_review()
        end
      end,
    },
    keymaps = {
      disable_defaults = false,
      view = {
        { "n", "<tab>", actions.select_next_entry, { desc = "Next entry" } },
        { "n", "<s-tab>", actions.select_prev_entry, { desc = "Prev entry" } },
        { "n", "gf", actions.goto_file_edit, { desc = "Open file" } },
        { "n", "<C-w><C-f>", actions.goto_file_split, { desc = "Open file in split" } },
        { "n", "<C-w>gf", actions.goto_file_tab, { desc = "Open file in tab" } },
        { "n", "<leader>e", actions.toggle_files, { desc = "Toggle file panel" } },
        { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } },
      },
      file_panel = {
        { "n", "j", actions.next_entry, { desc = "Next entry" } },
        { "n", "k", actions.prev_entry, { desc = "Prev entry" } },
        { "n", "<cr>", actions.select_entry, { desc = "Select entry" } },
        { "n", "o", actions.select_entry, { desc = "Select entry" } },
        { "n", "-", actions.toggle_stage_entry, { desc = "Stage/unstage entry" } },
        { "n", "s", actions.toggle_stage_entry, { desc = "Stage/unstage entry" } },
        { "n", "S", actions.stage_all, { desc = "Stage all" } },
        { "n", "U", actions.unstage_all, { desc = "Unstage all" } },
        { "n", "X", actions.restore_entry, { desc = "Restore (reject) entry" } },
        { "n", "R", actions.refresh_files, { desc = "Refresh" } },
        { "n", "<tab>", actions.select_next_entry, { desc = "Next entry" } },
        { "n", "<s-tab>", actions.select_prev_entry, { desc = "Prev entry" } },
        { "n", "gf", actions.goto_file_edit, { desc = "Open file" } },
        { "n", "<leader>e", actions.toggle_files, { desc = "Toggle file panel" } },
        { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } },
      },
      file_history_panel = {
        { "n", "j", actions.next_entry, { desc = "Next entry" } },
        { "n", "k", actions.prev_entry, { desc = "Prev entry" } },
        { "n", "<cr>", actions.select_entry, { desc = "Select entry" } },
        { "n", "o", actions.select_entry, { desc = "Select entry" } },
        { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close diffview" } },
      },
    },
  })
end

return M

