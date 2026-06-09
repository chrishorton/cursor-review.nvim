-- cursor-review.nvim commands module
-- User commands and global keymaps for the review workflow

local M = {}

local ui = require("cursor-review.ui")
local git = require("cursor-review.git")

--- Setup user commands
---@param config table Plugin configuration
function M.setup(config)
  local cmds = config.commands

  -- CursorCheckpoint: Create a checkpoint commit before running Cursor Agent
  if cmds.checkpoint then
    vim.api.nvim_create_user_command(cmds.checkpoint, function(opts)
      local msg = opts.args ~= "" and opts.args or "checkpoint before cursor agent"

      if not ui.is_git_repo() then
        vim.notify("Not a git repository", vim.log.levels.ERROR)
        return
      end

      -- Ensure alternate git dir exists (if configured)
      if git.is_enabled() and not git.ensure_initialized() then
        return
      end

      local status = ui.get_git_status()
      if status == "" then
        if config.notifications.enable then
          vim.notify("Working tree clean, no checkpoint needed", vim.log.levels.INFO)
        end
        return
      end

      -- Stage all and commit to the configured git dir
      vim.fn.system(git.cmd("add -A"))
      local result = vim.fn.system(git.cmd(string.format('commit -m "%s"', msg)))

      if vim.v.shell_error == 0 then
        if config.notifications.enable then
          local target = git.is_enabled() and " (to " .. config.git_dir .. ")" or ""
          vim.notify("Checkpoint created" .. target .. ": " .. msg, vim.log.levels.INFO)
        end
        if not git.is_enabled() then
          pcall(vim.cmd, "Gitsigns refresh")
        end
      else
        vim.notify("Checkpoint failed: " .. result, vim.log.levels.ERROR)
      end
    end, {
      nargs = "?",
      desc = "Create checkpoint commit before running Cursor Agent",
    })
  end

  -- CursorReview: Open diffview to review changes
  if cmds.review then
    vim.api.nvim_create_user_command(cmds.review, function()
      if not ui.is_git_repo() then
        vim.notify("Not a git repository", vim.log.levels.ERROR)
        return
      end

      -- If using alternate git dir, enter review mode (sets GIT_DIR env)
      if git.is_enabled() then
        if not git.has_commits() then
          vim.notify(
            "No checkpoint found. Run :" .. (cmds.checkpoint or "CursorCheckpoint") .. " first.",
            vim.log.levels.WARN
          )
          return
        end
        git.enter_review()
        -- Small delay to let gitsigns refresh before opening diffview
        vim.defer_fn(function()
          local status = ui.get_git_status()
          if status == "" then
            git.exit_review()
            if config.notifications.enable then
              vim.notify("No changes to review since checkpoint", vim.log.levels.INFO)
            end
            return
          end
          vim.cmd("DiffviewOpen")

          if config.notifications.enable and config.notifications.verbose then
            vim.notify(string.format(
              [[
Review Cursor changes (vs %s):
  ]c / [c     - Navigate hunks
  <leader>hs  - Accept (stage) hunk
  <leader>hr  - Reject (reset) hunk
  s / -       - Stage/unstage file
  X           - Restore (reject) file
  q           - Close diffview
  :%s   - Commit accepted changes
]],
              config.git_dir,
              cmds.finalize or "CursorFinalize"
            ), vim.log.levels.INFO)
          end
        end, 100)
        return
      end

      -- Standard mode (no alternate git dir)
      local status = ui.get_git_status()
      if status == "" then
        if config.notifications.enable then
          vim.notify("No changes to review", vim.log.levels.INFO)
        end
        return
      end

      vim.cmd("DiffviewOpen")

      if config.notifications.enable and config.notifications.verbose then
        vim.notify(
          [[
Review Cursor changes:
  ]c / [c     - Navigate hunks
  <leader>hs  - Accept (stage) hunk
  <leader>hr  - Reject (reset) hunk
  s / -       - Stage/unstage file
  X           - Restore (reject) file
  q           - Close diffview
  :CursorFinalize - Commit accepted changes
]],
          vim.log.levels.INFO
        )
      end
    end, {
      desc = "Open diffview to review Cursor Agent changes",
    })
  end

  -- CursorFinalize: Open floating commit dialog
  if cmds.finalize then
    vim.api.nvim_create_user_command(cmds.finalize, function()
      ui.show_commit_dialog(config, { amend = false })
    end, {
      desc = "Commit staged (accepted) changes with floating dialog",
    })
  end

  -- CursorAmend: Amend staged changes to previous commit
  if cmds.amend then
    vim.api.nvim_create_user_command(cmds.amend, function(opts)
      local staged_count = ui.get_staged_count()

      if staged_count == 0 then
        vim.notify(
          "No staged changes to amend. Use " .. config.keymaps.stage_hunk .. " to stage hunks.",
          vim.log.levels.WARN
        )
        return
      end

      local last_commit = ui.get_last_commit_message()
      if not last_commit then
        vim.notify("No previous commit to amend", vim.log.levels.ERROR)
        return
      end

      if not opts.bang then
        local result = vim.fn.system(git.cmd("commit --amend --no-edit"))
        if vim.v.shell_error == 0 then
          if config.notifications.enable then
            vim.notify("Amended commit: " .. last_commit, vim.log.levels.INFO)
          end
          pcall(vim.cmd, "Gitsigns refresh")
        else
          vim.notify("Amend failed: " .. result, vim.log.levels.ERROR)
        end
      else
        ui.show_commit_dialog(config, {
          amend = true,
          default_message = last_commit,
        })
      end
    end, {
      bang = true,
      desc = "Amend staged changes to previous commit (use ! to edit message)",
    })
  end

  -- CursorAbort: Reset all unstaged changes (restores to checkpoint state)
  if cmds.abort then
    vim.api.nvim_create_user_command(cmds.abort, function()
      local prompt = git.is_enabled()
        and "This will discard ALL changes since checkpoint. Continue?"
        or "This will discard ALL unstaged changes. Continue?"

      ui.confirm(prompt, function()
        vim.fn.system(git.cmd("checkout -- ."))
        pcall(vim.cmd, "Gitsigns refresh")
        vim.cmd("e!")
        if config.notifications.enable then
          vim.notify("All unstaged changes discarded", vim.log.levels.INFO)
        end
      end, function()
        if config.notifications.enable then
          vim.notify("Abort cancelled", vim.log.levels.INFO)
        end
      end)
    end, {
      desc = "Discard all unstaged (rejected) changes",
    })
  end

  -- CursorReviewEnd: Exit review mode (restore normal git env)
  if git.is_enabled() then
    vim.api.nvim_create_user_command("CursorReviewEnd", function()
      if git.in_review() then
        git.exit_review()
        if config.notifications.enable then
          vim.notify("Exited review mode, restored normal git", vim.log.levels.INFO)
        end
      else
        vim.notify("Not in review mode", vim.log.levels.INFO)
      end
    end, {
      desc = "Exit cursor-review mode and restore normal git environment",
    })
  end
end

--- Setup global keymaps for workflow commands
---@param config table Plugin configuration
function M.setup_keymaps(config)
  local km = config.keymaps
  local cmds = config.commands

  -- Workflow command keymaps
  if km.checkpoint and cmds.checkpoint then
    vim.keymap.set("n", km.checkpoint, ":" .. cmds.checkpoint .. "<CR>", {
      desc = "Create checkpoint before Cursor",
      silent = true,
    })
  end

  if km.review and cmds.review then
    vim.keymap.set("n", km.review, ":" .. cmds.review .. "<CR>", {
      desc = "Review Cursor changes",
      silent = true,
    })
  end

  if km.finalize and cmds.finalize then
    vim.keymap.set("n", km.finalize, ":" .. cmds.finalize .. "<CR>", {
      desc = "Finalize (commit) accepted changes",
      silent = true,
    })
  end

  if km.amend and cmds.amend then
    vim.keymap.set("n", km.amend, ":" .. cmds.amend .. "<CR>", {
      desc = "Amend (keep message) to previous commit",
      silent = true,
    })
  end

  if km.amend_edit and cmds.amend then
    vim.keymap.set("n", km.amend_edit, ":" .. cmds.amend .. "!<CR>", {
      desc = "Amend (edit message) to previous commit",
      silent = true,
    })
  end

  if km.abort and cmds.abort then
    vim.keymap.set("n", km.abort, ":" .. cmds.abort .. "<CR>", {
      desc = "Abort (discard) rejected changes",
      silent = true,
    })
  end

  -- Diffview keymaps
  if km.diffview_open then
    vim.keymap.set("n", km.diffview_open, ":DiffviewOpen<CR>", {
      desc = "Open Diffview",
      silent = true,
    })
  end

  if km.diffview_close then
    vim.keymap.set("n", km.diffview_close, ":DiffviewClose<CR>", {
      desc = "Close Diffview",
      silent = true,
    })
  end

  if km.diffview_history then
    vim.keymap.set("n", km.diffview_history, ":DiffviewFileHistory %<CR>", {
      desc = "File history",
      silent = true,
    })
  end
end

return M

