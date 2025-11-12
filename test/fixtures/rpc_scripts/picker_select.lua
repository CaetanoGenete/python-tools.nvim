-- For some reason sending '<CR>' doesn't seem to select the entry. Need to use the telescope
-- API instead.

local action_state = require("telescope.actions.state")
local action = require("telescope.actions")

local buf = vim.api.nvim_get_current_buf()
action.select_default(action_state.get_current_picker(buf).prompt_bufnr)
