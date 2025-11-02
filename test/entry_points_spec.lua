---@module "plenary.test_harness"

local tutils = require("test.utils")
local ep = require("python_tools.meta.entry_points")

---@param entry_points EntryPointDef[]
local function sort_entry_points(entry_points)
	table.sort(entry_points, function(lhs, rhs)
		return lhs.name < rhs.name
	end)
end

local function ep_def_fixture(...)
	local fixt = tutils.get_fixture(...)

	for _, value in ipairs(fixt) do
		value["lineno"] = nil
		value["rel_filepath"] = nil
	end

	return fixt
end

local MOCK_REPO_PATH = vim.fs.joinpath(TEST_PATH, "fixtures", "mock-repo")
local MOCK_SETUP_PY_REPO_PATH = vim.fs.joinpath(TEST_PATH, "fixtures", "mock-setup-py-repo")

local AENTRY_POINTS_CASES = {
	{
		use_importlib = true,
		opts = {},
		fixture = ep_def_fixture("entry_points", "mock_entry_points.json"),
	},
	{
		use_importlib = true,
		opts = { group = "my.group" },
		fixture = ep_def_fixture("entry_points", "mock_entry_points.json"),
	},
	{
		use_importlib = true,
		opts = { group = "non-existent-group" },
		fixture = {},
	},
	{
		use_importlib = false,
		opts = { search_dir = MOCK_SETUP_PY_REPO_PATH },
		fixture = ep_def_fixture("entry_points", "mock_setup_py_entry_points.json"),
	},
	{
		use_importlib = false,
		opts = { search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "some_other_dir") },
		fixture = ep_def_fixture("entry_points", "mock_setup_py_entry_points.json"),
	},
	{
		use_importlib = false,
		opts = {
			group = "other",
			search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "some_other_dir"),
		},
		fixture = ep_def_fixture("entry_points", "mock_setup_py_entry_points.json"),
	},
	{
		use_importlib = false,
		opts = {
			group = "non-existent-group",
			search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "some_other_dir"),
		},
		fixture = {},
	},
}

for _, case in ipairs(AENTRY_POINTS_CASES) do
	local test_name = "should list entry-points with"
	for key, value in pairs(case.opts) do
		if value ~= nil then
			test_name = test_name .. (" %s=`%s`"):format(key, value)
		end
	end

	describe("aentry_points tests:", function()
		it(test_name, function()
			local actual
			if case.use_importlib then
				actual = assert(ep.aentry_points_importlib(case.opts))
			else
				actual = assert(ep.aentry_points(case.opts))
			end
			sort_entry_points(actual)

			local expected = case.fixture
			-- If `group` is provided, filter fixture
			if case.opts.group ~= nil then
				expected = vim.fn.filter(expected, function(_, value)
					return value.group == case.opts.group
				end)
			end

			assert.same(expected, actual)
		end)
	end)
end

describe("aentry_points_from_project tests:", function()
	it("should correctly list all available entry_points from mock-setup-py-repo", function()
		local search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "setup.py")
		local actual = assert(ep.aentry_points_from_setuppy(search_dir))

		local expected = ep_def_fixture("entry_points", "mock_setup_py_entry_points.json")
		sort_entry_points(actual)

		assert.same(expected, actual)
	end)

	it("should fail if file is not the right format", function()
		local search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "some_other_dir", "placeholder.txt")
		local actual, err = ep.aentry_points_from_setuppy(search_dir)

		assert.no.same(err, nil)
		assert.same(actual, nil)
	end)
end)

local AENTRY_POINT_LOCATION_CASES = {
	{
		use_importlib = true,
		fixture = tutils.get_fixture("entry_points", "mock_entry_points.json"),
	},
	{
		use_importlib = false,
		opt = MOCK_REPO_PATH,
		fixture = tutils.get_fixture("entry_points", "mock_entry_points_ts_only.json"),
	},
}

for _, opts in ipairs(AENTRY_POINT_LOCATION_CASES) do
	local test_name = ("aentry_point_location tests, use_importlib = %s:"):format(opts.use_importlib)

	local function test_func(def)
		if opts.use_importlib then
			return ep.aentry_point_location_importlib(def, opts.opt)
		else
			return ep.aentry_point_location_ts(def, opts.opt)
		end
	end

	describe(test_name, function()
		-- Skip expected failing entries
		local fixt = vim.fn.filter(opts.fixture, function(_, value)
			return value.lineno ~= vim.NIL
		end)

		for _, case in ipairs(fixt) do
			it("should find the correct location for `" .. case.name .. "`", function()
				local actual = assert(test_func(case))
				local expected_path = vim.fs.joinpath(TEST_PATH, "fixtures", case.rel_filepath)

				assert.same(
					{ expected_path, case.lineno },
					{ vim.fs.normalize(actual.filename), actual.lineno }
				)
			end)
		end

		it("should fail for `ep5`", function()
			local def = {
				name = "ep5",
				group = "console_scripts",
				value = { "hello", "no_such_function" },
			}

			local result, err = test_func(def)
			assert.is_nil(result)
			assert.no.is_nil(err)
		end)
	end)
end
