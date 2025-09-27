local M = {}

local ns_previewer = vim.api.nvim_create_namespace("telescope.previewers")

--- Centers the viewport at `lnum` for the given `bufnr`.
---
--- Also moves the cursor to `winid`.
---@param winid integer
---@param bufnr integer
---@param lnum integer?
function M.jump_to_line(winid, bufnr, lnum)
	pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_previewer, 0, -1)
	if lnum == nil or lnum == 0 then
		return
	end

	pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_previewer, lnum - 1, 0, {
		end_row = lnum,
		hl_group = "TelescopePreviewLine",
	})
	pcall(vim.api.nvim_win_set_cursor, winid, { lnum, 0 })

	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("norm! zz")
	end)
end

function M.clear_cmdline()
	vim.api.nvim_echo({ { "" } }, false, {})
end

return M
