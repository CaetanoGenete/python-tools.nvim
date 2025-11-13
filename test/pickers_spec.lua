---@module "luassert"
---@module "busted"

require("test.utils.asserts")

local tutils = require("test.utils")
local pickers = require("python_tools.pickers")

local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")

local function wait_for_picker()
	local picker
	assert.poll(function()
		local buf = vim.api.nvim_get_current_buf()
		picker = action_state.get_current_picker(buf)
		return picker ~= nil
	end, { timeout = 3000 })

	return picker
end

local function search_selection(picker, name)
	local first_selected = action_state.get_selected_entry()
	local next = first_selected

	repeat
		if next.value.name == name then
			return
		end
		actions.move_selection_next(picker.prompt_bufnr)
		next = action_state.get_selected_entry()
	until first_selected == next

	assert(false, "Could not find " .. name)
end

local PICKER_TEST_CASES = {
	{
		use_importlib = true,
		group = nil,
		python_path = nil,
		search_dir = nil,
		fixture = tutils.fixt.get("entry_points", "mock_entry_points.json"),
	},
	{
		use_importlib = false,
		group = nil,
		python_path = nil,
		search_dir = tutils.fixt.path("mock-setup-py-repo"),
		fixture = tutils.fixt.get("entry_points", "mock_setup_py_entry_points.json"),
	},
}

describe("find_entry_points actions", function()
	for test_num, opts in ipairs(PICKER_TEST_CASES) do
		-- Skip expected failing entries
		local fixt = vim.fn.filter(opts.fixture, function(_, value)
			return value.lineno ~= vim.NIL
		end)

		for _, expected in pairs(fixt) do
			it(("should succeed to select '%s' (case %d)"):format(expected.name, test_num), function()
				tutils.log("find_entry_points opts: %s", opts)

				pickers.find_entry_points(opts)

				local picker = wait_for_picker()
				search_selection(picker, expected.name)

				actions.select_default(picker.prompt_bufnr)
				assert.paths_same(tutils.fixt.path(expected.rel_filepath), vim.api.nvim_buf_get_name(0))
			end)
		end
	end
end)

describe("find_entry_points actions", function()
	before_each(function()
		vim.fn.execute("messages clear", "silent")
	end)

	it("should fail to select ep5", function()
		pickers.find_entry_points()

		local picker = wait_for_picker()
		search_selection(picker, "ep5")

		local last_buff_name = vim.api.nvim_buf_get_name(0)
		actions.select_default(picker.prompt_bufnr)
		assert.paths_same(last_buff_name, vim.api.nvim_buf_get_name(0))

		local messages = vim.split(vim.fn.execute("messages", "silent"), "\n")
		assert.are.equal("Entry-point origin could not be found!", messages[#messages])
	end)
end)

---@param list table<string, any>
local function sort_qflist(list)
	table.sort(list, function(lhs, rhs)
		return lhs.text < rhs.text
	end)
end

local QFLIST_TEST_CASES = {
	{
		fixture = tutils.fixt.get("picker-actions", "send_all_to_qflist.json"),
		action = actions.send_to_qflist,
		list = "qf",
	},
	{
		fixture = tutils.fixt.get("picker-actions", "send_all_to_loclist.json"),
		action = actions.send_to_loclist,
		list = "loc",
	},
}

describe("find_entry_points actions", function()
	for test_num, case in ipairs(QFLIST_TEST_CASES) do
		it(("should be able to send all entries to the '%s' list"):format(case.list), function()
			tutils.log("Test case %d: %s", test_num, case)

			pickers.find_entry_points()

			local picker = wait_for_picker()
			case.action(picker.prompt_bufnr)

			local actual
			assert.poll(function()
				if case.list == "qf" then
					actual = vim.fn.getqflist()
				else
					actual = vim.fn.getloclist(picker.original_win_id)
				end
				return #actual > 0
			end)

			sort_qflist(actual)
			sort_qflist(case.fixture)

			assert.same(#case.fixture, #actual)
			for i = 1, #actual do
				assert.subset(case.fixture[i], actual[i])
			end
		end)
	end
end)

describe("find_entry_points", function()
	local nvim

	before_each(function()
		-- Spawn a new Neovim process in embedded mode with a UI. This is necessary as
		-- `find_entry_points` uses the previewer to lazy load entry-points. However, Telescope won't
		-- instantiate a previewer if no UI is active, or if the window cannot fit a previewer.
		nvim = vim.fn.jobstart(
			{ "nvim", "-u", "./scripts/minimal_init.lua", "--embed" },
			{ rpc = true }
		)
		vim.rpcrequest(nvim, "nvim_ui_attach", 140, 48, {})
	end)

	after_each(function()
		vim.fn.jobstop(nvim)
	end)

	it("should debounce selections", function()
		---@type EntryPointPickerOptions
		local picker_opts = {
			debounce_duration_ms = 200,
			-- Note: filtering, as this group has no error entry_points
			group = "my.group",
		}
		local fixt = tutils.fixt.get("entry_points", "mock_entry_points.json")

		-- Open picker
		vim.rpcrequest(
			nvim,
			"nvim_exec_lua",
			'require("python_tools.pickers").find_entry_points(...)',
			{ picker_opts }
		)

		-- Wait for the picker to become ready.
		assert.poll(function()
			local result = tutils.rpc.exec_lua(nvim, "picker_current_selection.lua")
			return result ~= nil and result ~= vim.NIL
		end, { interval = 15 })

		-- If navigating faster than debounce duration nothing should be loaded!
		for _ = 1, 3 do
			vim.wait(picker_opts.debounce_duration_ms - 40)
			local result = assert(tutils.rpc.exec_lua(nvim, "picker_current_selection.lua"))

			assert.is_nil(result.filename)
			assert.is_nil(result.lnum)

			vim.rpcrequest(nvim, "nvim_input", "<Up>")
		end

		---@type EntryPointEntry[]
		local entries = assert(tutils.rpc.exec_lua(nvim, "picker_all_results.lua"))
		assert.True(#entries > 0)

		-- Check no entry-point entries have been loaded.
		for _, entry in ipairs(entries) do
			assert.is_nil(entry.filename)
			assert.is_nil(entry.lnum)
		end

		-- Check the entry-point will be loaded eventually if user keeps it selected.
		assert.poll(function()
			local result = tutils.rpc.exec_lua(nvim, "picker_current_selection.lua")
			if result == nil or result == vim.NIL then
				return false
			end

			if result.filename ~= nil then
				result.filename = vim.fs.normalize(result.filename)
			end

			local expected = fixt[result.value.name]
			local expected_filename = tutils.fixt.path(expected.rel_filepath)

			return result.filename == expected_filename and result.lnum == expected.lineno
		end, { timeout = 10000 })
	end)

	it("will still select if debouncing", function()
		---@type EntryPointPickerOptions
		local picker_opts = {
			use_importlib = false,
			search_dir = tutils.fixt.path("mock-setup-py-repo"),
			debounce_duration_ms = 500,
			select_timeout_ms = 2000,
		}
		local fixt = tutils.fixt.get("entry_points", "mock_setup_py_entry_points.json")

		-- Open picker
		vim.rpcrequest(
			nvim,
			"nvim_exec_lua",
			'require("python_tools.pickers").find_entry_points(...)',
			{ picker_opts }
		)

		---@type EntryPointEntry
		local entry
		assert.poll(function()
			entry = tutils.rpc.exec_lua(nvim, "picker_current_selection.lua")
			return entry ~= nil and entry ~= vim.NIL
		end)
		tutils.log("Found entry: %s", entry)

		local expected_entry = fixt[entry.value.name]
		local expected_filename = tutils.fixt.path(expected_entry.rel_filepath)

		-- Verify current buffer isn't atached to the desired file.
		assert.no.equal(expected_filename, vim.rpcrequest(nvim, "nvim_buf_get_name", 0))

		tutils.rpc.exec_lua(nvim, "picker_select.lua")

		assert.poll(function()
			return expected_filename == vim.rpcrequest(nvim, "nvim_buf_get_name", 0)
		end)
	end)
end)
