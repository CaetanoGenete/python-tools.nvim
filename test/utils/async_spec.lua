require("test.utils")
require("plenary.busted")

local async = require("python_tools.utils._async")

describe("Test findfile:", function()
	local test_cases = {
		{
			start = vim.fs.joinpath(TEST_PATH, "mock-repo"),
			expected = vim.fs.joinpath(TEST_PATH, "mock-repo", "pyproject.toml"),
		},
		{
			start = vim.fs.joinpath(TEST_PATH, "mock-repo", "src"),
			expected = vim.fs.joinpath(TEST_PATH, "mock-repo", "pyproject.toml"),
		},
		{
			start = vim.fs.joinpath(TEST_PATH, "mock-setup-py-repo"),
			expected = vim.fs.joinpath(TEST_PATH, "mock-setup-py-repo", "setup.py"),
		},
	}

	for _, test_case in ipairs(test_cases) do
		local target = vim.fs.basename(test_case.expected)

		it("should find `" .. target .. "` from `" .. test_case.start .. "`", function()
			local actual, err = async.findfile(test_case.start, target)
			assert(actual, err)
			assert.are_same(test_case.expected, actual)
		end)
	end

	local bad_file = "non-existant-file.random-ext"
	it("should fail to find `" .. bad_file .. "`", function()
		local match, err = async.findfile(TEST_PATH, bad_file)
		assert.is_nil(match)
		assert.is_nil(err)
	end)
end)
