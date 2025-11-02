local async = require("python_tools._async")
local actions = require("telescope.actions")

local conf = require("telescope.config").values
local picker = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local entry_display = require("telescope.pickers.entry_display")
local action_set = require("telescope.actions.set")
local putils = require("telescope.previewers.utils")

local ep_tools = require("python_tools.meta.entry_points")
local ep_actions = require("python_tools.pickers._entry_point_actions")
local utils = require("python_tools.pickers._utils")

---@class	EntryPointPickerOptions
--- Whether to use python's [importlib](https://docs.python.org/3/library/importlib.html) module
--- when determining entrypoints.
---
--- If `true`, will use:
--- - [aentry_points_importlib](lua://entry_points.aentry_points_importlib)
--- - [aentry_point_location_importlib](lua://entry_points.aentry_point_location_importlib)
--- to evaluate all available entrypoints, and their location in source.
---
--- Otherwise, if `false`:
--- - [aentry_points](lua://entry_points.aentry_points)
--- - [aentry_point_location_ts](lua://entry_points.aentry_point_location_ts)
--- will be used instead.
---
--- The two modes are **not** intended to be interchangeable, and are unlikely to display the same
--- results. There are distinct advantages and disadvantages to either choice, a deeper discussion
--- of which is presented in the docstrings for:
--- - [aentry_points_importlib](lua://entry_points.aentry_points_importlib)
--- - [aentry_points](lua://entry_points.aentry_points)
---
--- Briefly, `use_importlib=true` is more accurate, while the converse is more *flexible*.
---
--- Defaults to `true`.
---@field use_importlib boolean?
--- Filter entrypoints by `group`.
---
--- See:
--- - [EntryPointsImportlibOptions.group](lua://EntryPointsImportlibOptions.group).
--- - [EntryPointsTSOptions.group](lua://EntryPointsTSOptions.group).
---
--- Defaults to `nil`.
---@field group string?
--- Only applicable if `use_importlib=false`.
---
--- See [EntryPointsTSOptions.python_path](lua://EntryPointsTSOptions.search_dir)
---
--- Defaults to `nil`.
---@field search_dir string?
--- Python binary used when executing python scripts.
---
--- *Note*: if `use_importlib=true`, this should be the environment whose entrypoints are of
--- interest.
---
--- See [EntryPointsImportlibOptions.python_path](lua://EntryPointsImportlibOptions.python_path)
--- See [EntryPointsTSOptions.python_path](lua://EntryPointsTSOptions.python_path)
---
--- Defaults to [default_path](lua://utils.default_path).
---@field python_path string?
--- Maximum display width, in the *results* window, for the entry-point group.
---
--- Defaults `12`.
---@field group_max_width integer?
--- The duration in milliseconds for which an entry should be selected, before the entry-point
--- location is fetched.
---
--- Defaults to `50`.
---@field debounce_duration_ms integer?
--- How long to wait, in milliseconds, for an entry-point to be found once selected, before throwing
--- an error.
---
--- Defaults to `2000`.
---@field select_timeout_ms integer?
--- Additional telescope options.
---@field [string] any

---@type EntryPointPickerOptions
local DEFAULT_EP_PICKER_CONFIG = {
	use_importlib = true,
	group = nil,
	python_path = nil,
	search_dir = nil,
	group_max_width = 12,
	debounce_duration_ms = 50,
	select_timeout_ms = 2000,
	preview = {},
}

local M = {}

---@class EntryPointEntry
---@field value EntryPointDef
---@field ordinal string
---@field displayer fun(...):...
---@field state "done"|"pending"|"debounce"|nil
---@field filename string?
---@field lnum integer?

---@class PreviewerState
---@field bufnr integer
---@field winid integer
---@field bufname string?

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
				utils.jump_to_line(state.winid, bufnr, entry.lnum)
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

			if entry.state == "done" then
				render_entry(self.state, entry, opts)
				return
			end

			if entry.state == "pending" or entry.state == "debounce" then
				return
			end

			entry.state = "debounce"
			async.run(function()
				-- Debounce helps prevent freezing/blocking if navigating too fast.
				-- E.g. holding down arrow keys.
				if opts.debounce_duration_ms > 0 then
					async.sleep(opts.debounce_duration_ms)
					if selected ~= entry then
						entry.state = nil
						return
					end
				end

				ep_actions.aset_entry_point_location(entry, opts)

				-- Avoid rendering if the user has selected something else in the meantime
				if selected == entry then
					render_entry(self.state, entry, opts)
				end
			end)
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

	local attach_mappings = function()
		---@diagnostic disable-next-line: undefined-field
		action_set.select:replace(ep_actions.select(opts))

		actions.send_selected_to_qflist:replace(ep_actions.send_selected_eps_to_qf(opts, " ", "qf"))
		actions.add_selected_to_qflist:replace(ep_actions.send_selected_eps_to_qf(opts, "a", "qf"))
		actions.send_to_qflist:replace(ep_actions.send_all_eps_to_qf(opts, " ", "qf"))
		actions.add_to_qflist:replace(ep_actions.send_all_eps_to_qf(opts, "a", "qf"))

		actions.send_selected_to_loclist:replace(ep_actions.send_selected_eps_to_qf(opts, " ", "loc"))
		actions.add_selected_to_loclist:replace(ep_actions.send_selected_eps_to_qf(opts, "a", "loc"))
		actions.send_to_loclist:replace(ep_actions.send_all_eps_to_qf(opts, " ", "loc"))
		actions.add_to_loclist:replace(ep_actions.send_all_eps_to_qf(opts, "a", "loc"))

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

--- Telescope picker (with preview) for python entry-points.
---@param opts EntryPointPickerOptions? picker options.
function M.find_entry_points(opts)
	---@type EntryPointPickerOptions
	opts = vim.tbl_extend("force", DEFAULT_EP_PICKER_CONFIG, opts or {})

	local on_endpoints = function(ok, eps, errmsg)
		if not ok then
			vim.notify("An unknown error occured while getting entry-points!", vim.log.levels.ERROR)
			return
		end

		if eps == nil then
			vim.notify(("Error! %s"):format(errmsg), vim.log.levels.ERROR)
			return
		end

		if #eps == 0 then
			vim.notify("No entry-points found.", vim.log.levels.WARN)
			return
		end

		utils.clear_cmdline()
		pick_entry_point(eps, opts)
	end

	vim.notify("Fetching entry-points from environment...", vim.log.levels.INFO)
	if opts.use_importlib then
		async.run_callback(ep_tools.aentry_points_importlib, on_endpoints, opts)
	else
		async.run_callback(ep_tools.aentry_points, on_endpoints, opts)
	end
end

return M
