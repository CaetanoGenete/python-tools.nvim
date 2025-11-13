---@module "luassert"
---@module "busted"

require("test.utils.asserts")

local tutils = require("test.utils")
local ep = require("python_tools.meta.entry_points")

local async = tutils.async

---@param entry_points EntryPointDef[]
local function sort_entry_points(entry_points)
	table.sort(entry_points, function(lhs, rhs)
		return lhs.name < rhs.name
	end)
end

local function ep_def_fixture(...)
	local fixt = vim.tbl_values(tutils.fixt.get(...))

	for _, value in ipairs(fixt) do
		value["lineno"] = nil
		value["rel_filepath"] = nil
	end

	sort_entry_points(fixt)
	return fixt
end

local MOCK_REPO_PATH = tutils.fixt.path("mock-repo")
local MOCK_SETUP_PY_REPO_PATH = tutils.fixt.path("mock-setup-py-repo")

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

describe("aentry_points_*", function()
	for test_num, case in ipairs(AENTRY_POINTS_CASES) do
		async(it, ("should succeed (case %d)"):format(test_num), function()
			tutils.log("Test case: %s", case)

			local actual
			if case.use_importlib then
				actual = assert(ep.aentry_points_importlib(case.opts))
			else
				actual = assert(ep.aentry_points(case.opts))
			end
			sort_entry_points(actual)

			local expected = case.fixture
			if case.opts.group ~= nil then
				-- If `group` is provided, filter fixture
				expected = vim.fn.filter(expected, function(_, value)
					return value.group == case.opts.group
				end)
			end

			assert.same(vim.tbl_values(expected), actual)
		end)
	end
end)

describe("aentry_points_from_project", function()
	async(it, "should list all entry_points from mock-setup-py-repo", function()
		local search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "setup.py")
		local actual = assert(ep.aentry_points_from_setuppy(search_dir))

		local expected = ep_def_fixture("entry_points", "mock_setup_py_entry_points.json")
		sort_entry_points(actual)

		assert.same(expected, actual)
	end)

	async(it, "should fail if file is not the right format", function()
		local search_dir = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "some_other_dir", "placeholder.txt")
		local actual, err = ep.aentry_points_from_setuppy(search_dir)

		assert.no.same(err, nil)
		assert.same(actual, nil)
	end)
end)

local AENTRY_POINT_LOCATION_CASES = {
	{
		use_importlib = true,
		fixture = tutils.fixt.get("entry_points", "mock_entry_points.json"),
	},
	{
		use_importlib = false,
		opt = MOCK_REPO_PATH,
		fixture = tutils.fixt.get("entry_points", "mock_entry_points_ts_only.json"),
	},
}

---@async
---@param def EntryPointDef
---@param opts any
---@return EntryPoint?, string?
local function atest_func(def, opts)
	if opts.use_importlib then
		return ep.aentry_point_location_importlib(def, opts.opt)
	else
		return ep.aentry_point_location_ts(def, opts.opt)
	end
end

for _, opts in ipairs(AENTRY_POINT_LOCATION_CASES) do
	-- Skip expected failing entries
	local fixt = vim.fn.filter(opts.fixture, function(_, value)
		return value.lineno ~= vim.NIL
	end)

	local test_name = ("aentry_point_location_* importlib=%s"):format(opts.use_importlib)
	describe(test_name, function()
		for _, case in pairs(fixt) do
			async(it, ("should find the correct location for `%s`"):format(case.name), function()
				local actual = assert(atest_func(case, opts))
				local expected_path = tutils.fixt.path(case.rel_filepath)

				assert.paths_same(expected_path, actual.filename)
				assert.same(case.lineno, actual.lineno)
			end)
		end

		async(it, "should fail for ep5", function()
			local def = {
				name = "ep5",
				group = "console_scripts",
				value = { "hello", "no_such_function" },
			}

			local result, err = atest_func(def, opts)
			assert.is_nil(result)
			assert.no.is_nil(err)
		end)
	end)
end
