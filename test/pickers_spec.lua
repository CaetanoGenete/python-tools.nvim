require("luassert")

local tutils = require("test.utils")

local pickers = require("python_tools.pickers")

local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

local function assert_poll(time, func, ...)
	local args = { ... }

	vim.wait(time, function()
		return func(unpack(args))
	end)

	local passed = func(unpack(args))
	assert.are_true(passed, "Assert poll timeout!")
end

local function wait_for_picker()
	local picker
	assert_poll(8000, function()
		local buf = vim.api.nvim_get_current_buf()
		picker = action_state.get_current_picker(buf)
		return picker ~= nil
	end)
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

	error("Could not find " .. name)
end

local function assert_paths_same(expected, actual)
	assert.are_same(vim.fs.normalize(expected), vim.fs.normalize(actual))
end

local MOCK_SETUP_PY_REPO_PATH = vim.fs.joinpath(TEST_PATH, "fixtures", "mock-setup-py-repo")

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
		search_dir = MOCK_SETUP_PY_REPO_PATH,
		fixture = tutils.get_fixture("entry_points", "mock_setup_py_entry_points.json"),
	},
}

for _, opts in ipairs(PICKER_TEST_CASES) do
	describe("Test entry_points picker: select successful -", function()
		-- Skip expected failing entries
		local fixt = vim.fn.filter(opts.fixture, function(_, value)
			return value.lineno ~= vim.NIL
		end)

		for _, expected in ipairs(fixt) do
			it(expected.name, function()
				pickers.find_entry_points(opts)

				local picker = wait_for_picker()
				search_selection(picker, expected.name)

				actions.select_default(picker.prompt_bufnr)
				assert_paths_same(
					vim.fs.joinpath(TEST_PATH, "fixtures", expected.rel_filepath),
					vim.api.nvim_buf_get_name(0)
				)
			end)
		end
	end)
end

describe("Test entry_points picker: select failure -", function()
	it("ep5", function()
		pickers.find_entry_points()

		local picker = wait_for_picker()
		search_selection(picker, "ep5")

		local last_buff_name = vim.api.nvim_buf_get_name(0)
		actions.select_default(picker.prompt_bufnr)
		assert_paths_same(last_buff_name, vim.api.nvim_buf_get_name(0))
	end)
end)
