---@module "luassert"

local async = require("test.utils").async
local a = require("python_tools._async")

local MOCK_REPO_PATH = vim.fs.joinpath(TEST_PATH, "fixtures", "mock-repo")
local MOCK_SETUP_PY_REPO_PATH = vim.fs.joinpath(TEST_PATH, "fixtures", "mock-setup-py-repo")

describe("Test findfile:", function()
	local test_cases = {
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

	for _, test_case in ipairs(test_cases) do
		local target = vim.fs.basename(test_case.expected)

		async(it, "should find `" .. target .. "` from `" .. test_case.start .. "`", function()
			local actual = assert(a.findfile(test_case.start, target))
			assert.are_same(test_case.expected, actual)
		end)
	end

	local bad_file = "non-existant-file.random-ext"
	async(it, "should fail to find `" .. bad_file .. "`", function()
		local match, err = a.findfile(TEST_PATH, bad_file)
		assert.is_nil(match)
		assert.no.is_nil(err)
	end)
end)
