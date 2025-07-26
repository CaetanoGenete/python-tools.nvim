local async = require("python_tools.utils._async")

local conf = require("telescope.config").values
local picker = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local entry_display = require("telescope.pickers.entry_display")
local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")
local putils = require("telescope.previewers.utils")

local ep_tools = require("python_tools.entry_points")

---@class	EntryPointPickerOptions
---Maximum display width for entry-point group. Defaults `12`.
---@field group_max_width integer?
---Defaults to `⎸`.
---@field group_separator string?
---If empty, pick from all available groups. Otherwise show only the provided
---`group`. Defaults to `nil`.
---@field group string?
---The duration in milliseconds for which an entry should be selected, before
---the entry-point location is fetched. Defaults to `20`.
---@field debounce_duration_ms integer?
---How long to wait, in milliseconds, for an entry-point to be found once
---selected. Defaults to `2000`.
---@field select_timeout_ms integer?
---Additional telescope options.
---@field [string] any

---@type EntryPointPickerOptions
local DEFAULT_EP_PICKER_CONFIG = {
	group_max_width = 12,
	group_separator = "⎸",
	debounce_duration_ms = 50,
	select_timeout_ms = 2000,
	preview = {},
}

-- For highlighting purposes
local ns_previewer = vim.api.nvim_create_namespace("telescope.previewers")

local M = {}

---Centers the viewport at `lnum` for the given `bufnr`.
---
---Also moves the cursor to `winid`.
---@param winid integer
---@param bufnr integer
---@param lnum integer?
local jump_to_line = function(winid, bufnr, lnum)
	pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_previewer, 0, -1)
	if lnum == nil or lnum == 0 then
		return
	end

	---@diagnostic disable-next-line: deprecated
	pcall(vim.api.nvim_buf_add_highlight, bufnr, ns_previewer, "TelescopePreviewLine", lnum - 1, 0, -1)
	pcall(vim.api.nvim_win_set_cursor, winid, { lnum, 0 })

	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("norm! zz")
	end)
end

---@class PreviewerState
---@field bufnr integer
---@field winid integer
---@field bufname string?

---@class EntryPointEntry
---@field value EntryPointDef
---@field ordinal string
---@field displayer fun(...):...
---@field state "done"|"pending"|nil
---@field filename string?
---@field lnum integer?

---@param state PreviewerState
---@param entry EntryPointEntry
---@param opts EntryPointPickerOptions
local function render_entry(state, entry, opts)
	if entry.filename then
		conf.buffer_previewer_maker(entry.filename, state.bufnr, {
			bufname = state.bufname,
			winid = state.winid,
			preview = opts.preview,
			---@param bufnr integer
			callback = function(bufnr)
				jump_to_line(state.winid, bufnr, entry.lnum)
			end,
			file_encoding = opts.file_encoding,
		})
	else
		vim.schedule_wrap(putils.set_preview_message)(
			state.bufnr,
			state.winid,
			"Cannot find entrypoint!",
			opts.preview.msg_bg_fillchar
		)
	end
end

---@param eps EntryPointDef[]
---@param opts EntryPointPickerOptions picker options.
local function pick_entry_point(eps, opts)
	local group_width = 0
	for _, ep in ipairs(eps) do
		local len = #ep.group
		if len >= opts.group_max_width then
			group_width = opts.group_max_width
			break
		end
		group_width = math.max(group_width, len)
	end

	local displayer = entry_display.create({
		separator = opts.group_separator,
		items = {
			{ width = group_width },
			{ remaining = true },
		},
	})

	local display = function(entry)
		return displayer({
			{ entry.value.group, "TelescopeResultsNumber" },
			entry.value.name,
		})
	end

	-- The currently selected entry
	local selected = nil

	local previewer = previewers.new_buffer_previewer({
		title = "Entry-point Preview",
		teardown = function()
			-- prevent async job from rendering if the previewer has closed
			selected = nil
		end,
		---@param entry EntryPointEntry
		define_preview = function(self, entry, _)
			selected = entry

			if entry.state == "pending" then
				return
			end

			if entry.state == "done" then
				render_entry(self.state, entry, opts)
			else
				async.run(function()
					-- Debounce helps prevent freezing/blocking if navigating too fast.
					-- E.g. holding down arrow keys.
					if opts.debounce_duration_ms > 0 then
						async.sleep(opts.debounce_duration_ms)
						if selected ~= entry then
							return
						end
					end

					entry.state = "pending"
					local ok, filename, lnum = pcall(ep_tools.aentry_point_location, entry.value)
					entry.state = "done"

					if ok then
						entry.filename = filename
						entry.lnum = lnum
					end

					-- Avoid rendering if the user has selected something else in the meantime
					if selected == entry then
						render_entry(self.state, entry, opts)
					end
				end)
			end
		end,
	})

	local finder = finders.new_table({
		results = eps,
		---@param item EntryPointDef
		---@return EntryPointEntry
		entry_maker = function(item)
			return {
				value = item,
				ordinal = item.group .. " " .. item.name,
				display = display,
			}
		end,
	})

	local select_timeout_s = opts.select_timeout_ms / 1000

	local attach_mappings = function()
		---@diagnostic disable-next-line: undefined-field
		action_set.select:replace(function(prompt_bufnr, type)
			---@type EntryPointEntry
			local entry = action_state.get_selected_entry()

			local start_time = os.clock()
			-- Block for for `timeout` or until fetching entry-point finishes.
			while entry.state == "pending" do
				vim.notify("Looking for entry-point's origin, please wait...")
				if (os.clock() - start_time) > select_timeout_s then
					break
				end
				vim.cmd("sleep 10m")
			end

			if entry.filename ~= nil then
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
		end)
		return true
	end

	picker
		.new(opts, {
			prompt_title = "Entry points",
			sorter = conf.generic_sorter(opts),
			previewer = previewer,
			finder = finder,
			attach_mappings = attach_mappings,
		})
		:find()
end

---Telescope picker (with preview) for python entry-points.
---@param opts EntryPointPickerOptions? picker options.
M.find_entry_points = function(opts)
	---@type EntryPointPickerOptions
	opts = vim.tbl_extend("force", DEFAULT_EP_PICKER_CONFIG, opts or {})

	local on_endpoints = function(ok, eps)
		if not ok then
			vim.notify("An error occured while getting entry-points!", vim.log.levels.ERROR)
			return
		end

		if #eps == 0 then
			vim.notify("No entry-points found.", vim.log.levels.WARN)
			return
		end

		pick_entry_point(eps, opts)
	end

	vim.notify("Fetching entry-points from environment...", vim.log.levels.INFO)
	async.run_callback(ep_tools.aentrypoints, on_endpoints, opts.group)
end

return M
