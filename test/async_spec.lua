---@module "luassert"
---@module "busted"

local tutils = require("test.utils")
local a = require("python_tools._async")

local async = tutils.async

local MOCK_REPO_PATH = tutils.fixt.path("mock-repo")
local MOCK_SETUP_PY_REPO_PATH = tutils.fixt.path("mock-setup-py-repo")

local TEST_CASES = {
	{
		start = MOCK_REPO_PATH,
		expected = vim.fs.joinpath(MOCK_REPO_PATH, "pyproject.toml"),
	},
	{
		start = vim.fs.joinpath(MOCK_REPO_PATH, "src"),
		expected = vim.fs.joinpath(MOCK_REPO_PATH, "pyproject.toml"),
	},
	{
		start = MOCK_SETUP_PY_REPO_PATH,
		expected = vim.fs.joinpath(MOCK_SETUP_PY_REPO_PATH, "setup.py"),
	},
}

describe("findfile", function()
	for test_num, test_case in ipairs(TEST_CASES) do
		local target = vim.fs.basename(test_case.expected)

		async(it, ("should succeed (case %d)"):format(test_num), function()
			tutils.log("Test case: %s", test_case)

			local actual = assert(a.findfile(test_case.start, target))
			assert.are_same(test_case.expected, actual)
		end)
	end

	local bad_file = "non-existant-file.random-ext"
	async(it, ("should fail to find `%s`"):format(bad_file), function()
		local match, err = a.findfile("./test/", bad_file)
		assert.is_nil(match)
		assert.no.is_nil(err)
	end)
end)
