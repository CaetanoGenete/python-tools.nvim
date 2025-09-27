local M = {}

local action_state = require("telescope.actions.state")
local async = require("python_tools._async")

local ep_tools = require("python_tools.meta.entry_points")
local utils = require("python_tools.pickers._utils")
local action_set = require("telescope.actions.set")

---@param entry EntryPointEntry
---@param opts EntryPointPickerOptions
function M.aset_entry_point_location(entry, opts)
	entry.state = "pending"

	local ok, ep
	if opts.use_importlib then
		ok, ep = pcall(ep_tools.aentry_point_location_importlib, entry.value, opts.python_path)
	else
		ok, ep = pcall(ep_tools.aentry_point_location_ts, entry.value, opts.search_dir)
	end

	if ok and ep ~= nil then
		entry.filename = ep.filename
		entry.lnum = ep.lineno
	end

	entry.state = "done"
end

---@param opts EntryPointPickerOptions
function M.select(opts)
	return function(prompt_bufnr, type)
		---@type EntryPointEntry
		local entry = action_state.get_selected_entry()

		if entry.state == nil then
			async.run(M.aset_entry_point_location, entry, opts)
		end

		vim.wait(opts.select_timeout_ms, function()
			return entry.state == "done"
		end, 10)

		if entry.filename ~= nil then
			utils.clear_cmdline()
			action_set.edit(prompt_bufnr, action_state.select_key_to_edit_key(type))
			return
		end

		local errmsg = ""
		if entry.state == "pending" then
			errmsg = "Entry-point took too long to find! Try again, or skip."
		elseif entry.state == "done" then
			errmsg = "Entry-point origin could not be found!"
		else
			errmsg = "Something went wrong!"
		end
		vim.notify(errmsg, vim.log.levels.ERROR)
	end
end

return M
