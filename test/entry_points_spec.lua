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
		group = nil,
		python_path = nil,
		search_dir = nil,
		fixture = ep_def_fixture("entry_points", "mock_entry_points.json"),
	},
	{
		use_importlib = true,
		group = "my.group",
		python_path = nil,
		search_dir = nil,
		fixture = ep_def_fixture("entry_points", "mock_entry_points.json"),
	},
	{
		use_importlib = true,
		group = "non-existent-group",
		python_path = nil,
		search_dir = nil,
		fixture = {},
	},
	{
		use_importlib = false,
		group = nil,
		python_path = nil,
		search_dir = MOCK_SETUP_PY_REPO_PATH,
		fixture = ep_def_fixture("entry_points", "mock_setup_py_entry_points.json"),
	},
	{
		use_importlib = false,
		group = nil,
		python_path = nil,
		search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "some_other_dir"),
		fixture = ep_def_fixture("entry_points", "mock_setup_py_entry_points.json"),
	},
	{
		use_importlib = false,
		group = "other",
		python_path = nil,
		search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "some_other_dir"),
		fixture = ep_def_fixture("entry_points", "mock_setup_py_entry_points.json"),
	},
	{
		use_importlib = false,
		group = "non-existent-group",
		python_path = nil,
		search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "some_other_dir"),
		fixture = {},
	},
}

for _, opts in ipairs(AENTRY_POINTS_CASES) do
	local test_name = "should list entry-points with"
	for key, value in pairs(opts) do
		if key ~= "fixture" and value ~= nil then
			test_name = test_name .. (" %s=`%s`"):format(key, value)
		end
	end

	describe("aentry_points tests:", function()
		it(test_name, function()
			local actual = ep.aentry_points(opts)
			sort_entry_points(actual)

			local expected = opts.fixture
			-- If `group` is provided, filter fixture
			if opts.group ~= nil then
				expected = vim.fn.filter(expected, function(_, value)
					return value.group == opts.group
				end)
			end

			assert.same(expected, actual)
		end)
	end)
end

describe("aentry_points_from_project tests:", function()
	it("should correctly list all available entry_points from mock-setup-py-repo", function()
		local search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "setup.py")
		local actual = assert(ep.aentry_points_from_project(search_dir))

		local expected = ep_def_fixture("entry_points", "mock_setup_py_entry_points.json")
		sort_entry_points(actual)

		assert.same(expected, actual)
	end)
end)

local AENTRY_POINT_LOCATION_CASES = {
	{
		use_importlib = true,
		search_dir = nil,
		python_path = nil,
		fixture = tutils.get_fixture("entry_points", "mock_entry_points.json"),
	},
	{
		use_importlib = false,
		search_dir = MOCK_REPO_PATH,
		python_path = nil,
		fixture = tutils.get_fixture("entry_points", "mock_entry_points_ts_only.json"),
	},
}

for _, opts in ipairs(AENTRY_POINT_LOCATION_CASES) do
	local test_name = ("aentry_point_location tests, use_importlib = %s:"):format(opts.use_importlib)

	describe(test_name, function()
		-- Skip expected failing entries
		local fixt = vim.fn.filter(opts.fixture, function(_, value)
			return value.lineno ~= vim.NIL
		end)

		for _, case in ipairs(fixt) do
			it("should find the correct location for `" .. case.name .. "`", function()
				local actual, errmsg = ep.aentry_point_location(case, opts)
				assert(actual, errmsg)
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

			local result, err = ep.aentry_point_location(def, opts)
			assert.is_nil(result)
			assert.no.is_nil(err)
		end)
	end)
end
