---@module "luassert"
---@module "busted"

require("test.asserts")

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
		fixture = tutils.get_fixture("entry_points", "mock_entry_points.json"),
	},
	{
		use_importlib = false,
		group = nil,
		python_path = nil,
		search_dir = vim.fs.joinpath(TEST_PATH, "fixtures/mock-setup-py-repo"),
		fixture = tutils.get_fixture("entry_points", "mock_setup_py_entry_points.json"),
	},
}

describe("Test entry_points picker: select successful -", function()
	for test_num, opts in ipairs(PICKER_TEST_CASES) do
		-- Skip expected failing entries
		local fixt = vim.fn.filter(opts.fixture, function(_, value)
			return value.lineno ~= vim.NIL
		end)

		for _, expected in ipairs(fixt) do
			it(("test %d - entry point '%s'"):format(test_num, expected.name), function()
				tutils.log("find_entry_points opts: %s", opts)

				pickers.find_entry_points(opts)

				local picker = wait_for_picker()
				search_selection(picker, expected.name)

				actions.select_default(picker.prompt_bufnr)
				assert.paths_same(
					vim.fs.joinpath(TEST_PATH, "fixtures", expected.rel_filepath),
					vim.api.nvim_buf_get_name(0)
				)
			end)
		end
	end
end)

describe("Test entry_points picker: select failure -", function()
	before_each(function()
		vim.fn.execute("messages clear", "silent")
	end)

	it("ep5", function()
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
		fixture = tutils.get_fixture("picker-actions", "send_all_to_qflist.json"),
		action = actions.send_to_qflist,
		list = "qf",
	},
	{
		fixture = tutils.get_fixture("picker-actions", "send_all_to_loclist.json"),
		action = actions.send_to_loclist,
		list = "loc",
	},
}

describe("Test entry_points picker: send to quickfix -", function()
	for test_num, case in ipairs(QFLIST_TEST_CASES) do
		it(("Should send all entries to '%s' list"):format(case.list), function()
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

describe("find_files", function()
	local nvim

	before_each(function()
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
		local debounce_duration_ms = 200

		-- Open picker
		vim.rpcrequest(
			nvim,
			"nvim_exec_lua",
			([[
				require("python_tools.pickers").find_entry_points({debounce_duration_ms = %d})
			]]):format(debounce_duration_ms),
			{}
		)

		-- If navigating faster than debounce duration, then nothing should be loaded!
		for _ = 1, 5 do
			vim.wait(debounce_duration_ms * 0.8)
			local result = vim.rpcrequest(
				nvim,
				"nvim_exec_lua",
				[[
					local entry = require("telescope.actions.state").get_selected_entry()
					if entry == nil then
						return nil
					end

					return {
						entry.lnum or "_no_value_",
						entry.filename or "_no_value_",
					}
				]],
				{}
			)
			assert.same({ "_no_value_", "_no_value_" }, result)
			vim.rpcrequest(nvim, "nvim_input", "<Up>")
		end

		local entries = assert(vim.rpcrequest(
			nvim,
			"nvim_exec_lua",
			[[
				local action_state = require("telescope.actions.state")
				local buf = vim.api.nvim_get_current_buf()
				local results = action_state.get_current_picker(buf).finder.results

				return vim.tbl_map(function(x)
					return {x.lnum or "_no_value_", x.filename or "_no_value_"}
				end, results)
			]],
			{}
		))
		assert.True(#entries > 0)

		--- Check no entry-point entries have been loaded
		for _, entry in ipairs(entries) do
			assert.same({ "_no_value_", "_no_value_" }, entry)
		end

		-- Check the entry-point will be loaded eventually.
		assert.poll(function()
			local result = vim.rpcrequest(
				nvim,
				"nvim_exec_lua",
				[[
					local entry = require("telescope.actions.state").get_selected_entry()
					return {
						entry.lnum or "_no_value_",
						entry.filename or "_no_value_",
					}
				]],
				{}
			)
			return result ~= nil and result[1] ~= "_no_value_" and result[2] ~= "_no_value_"
		end, { timeout = 10000 })
	end)

	it("will still select if debouncing", function()
		local debounce_duration_ms = 200

		-- Open picker
		vim.rpcrequest(
			nvim,
			"nvim_exec_lua",
			([[
				require("python_tools.pickers").find_entry_points({debounce_duration_ms = %d})
			]]):format(debounce_duration_ms),
			{}
		)

		---@type EntryPointDef
		local entry

		assert.poll(function()
			local resp = vim.rpcrequest(
				nvim,
				"nvim_exec_lua",
				[[
					local entry = require("telescope.actions.state").get_selected_entry()
					if entry == nil then
						return nil
					end

					return entry.value
				]],
				{}
			)

			if resp == nil then
				return false
			end
			entry = resp

			return entry ~= vim.NIL
		end)

		assert.equal("", vim.rpcrequest(nvim, "nvim_buf_get_name", 0))

		vim.rpcrequest(
			nvim,
			"nvim_exec_lua",
			[[
				local action_state = require("telescope.actions.state")
				local action = require("telescope.actions")

				local buf = vim.api.nvim_get_current_buf()
				action.select_default(action_state.get_current_picker(buf).prompt_bufnr)
			]],
			{}
		)

		assert.poll(function()
			local result = vim.rpcrequest(nvim, "nvim_buf_get_name", 0)
			return result ~= nil and #result > 0
		end)
	end)
end)
