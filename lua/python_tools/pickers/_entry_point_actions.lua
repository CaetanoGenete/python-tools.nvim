local M = {}

local action_state = require("telescope.actions.state")
local async = require("python_tools._async")

local ep_tools = require("python_tools.meta.entry_points")
local utils = require("python_tools.pickers._utils")
local action_set = require("telescope.actions.set")
local actions = require("telescope.actions")

---@param entry EntryPointEntry
---@param opts EntryPointPickerOptions
---@return EntryPointEntry
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
	return entry
end

---@param eps EntryPointEntry[]
---@param opts EntryPointPickerOptions
local function wait_completed(eps, opts)
	local pending = 0

	for _, entry in ipairs(eps) do
		if entry.state ~= "done" then
			pending = pending + 1
		end

		if entry.state == nil then
			async.run_callback(M.aset_entry_point_location, function(ok, _entry)
				if ok and _entry.state == "done" then
					pending = pending - 1
				end
			end, entry, opts)
		end
	end

	vim.wait(opts.select_timeout_ms, function()
		return pending == 0
	end, 10)
end

---@param opts EntryPointPickerOptions
function M.select(opts)
	return function(prompt_bufnr, type)
		---@type EntryPointEntry
		local entry = action_state.get_selected_entry()
		wait_completed({ entry }, opts)

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

---@param eps EntryPointEntry[]
---@param opts EntryPointPickerOptions
---@param picker any
---@param mode string?
---@param target "loc"|"qf"
local function _eps_to_entries(eps, opts, picker, mode, target)
	wait_completed(eps, opts)

	local qf_entries = {}
	for _, ep in ipairs(eps) do
		local entry = {
			filename = ep.filename,
			lnum = ep.lnum,
			col = 1,
			text = "(" .. ep.value.group .. ") " .. ep.value.name,
		}

		-- If the entrypoint cannot be found, still display it, but with an error.
		if ep.filename == nil then
			entry.lnum = 1
			entry.type = "E"
		end

		table.insert(qf_entries, entry)
	end

	---@diagnostic disable-next-line: undefined-field
	local what = { title = picker.prompt_title }

	if target == "loc" then
		vim.fn.setloclist(picker.original_win_id, qf_entries, mode)
		vim.fn.setloclist(picker.original_win_id, {}, "a", what)
	elseif target == "qf" then
		vim.fn.setqflist(qf_entries, mode)
		vim.fn.setqflist({}, "a", what)
	else
		error(("Unknown option '%s'"):format(target))
	end

	return qf_entries
end

--- Creates replacement telescope action to send selected entrypoints to qflist or loclist.
---
---@param opts EntryPointPickerOptions
---@param mode string?
---@param target "loc"|"qf"
---@return fun(prompt_bufnr: number)
function M.send_selected_eps_to_qf(opts, mode, target)
	return function(prompt_bufnr)
		local picker = action_state.get_current_picker(prompt_bufnr)
		actions.close(prompt_bufnr)
		_eps_to_entries(picker:get_multi_selection(), opts, picker, mode, target)
	end
end

--- Creates replacement telescope action to send all entrypoints to qflist or loclist.
---
---@param opts EntryPointPickerOptions
---@param mode string?
---@param target "loc"|"qf"
---@return fun(prompt_bufnr: number)
function M.send_all_eps_to_qf(opts, mode, target)
	return function(prompt_bufnr)
		local picker = action_state.get_current_picker(prompt_bufnr)

		local entries = {}
		for entry in picker.manager:iter() do
			table.insert(entries, entry)
		end

		actions.close(prompt_bufnr)
		_eps_to_entries(entries, opts, picker, mode, target)
	end
end

return M
