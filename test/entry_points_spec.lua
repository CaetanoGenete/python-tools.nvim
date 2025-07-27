---@module "plenary.test_harness"

local ep = require("python_tools.entry_points")

local function aentry_points(group)
	local actual = ep.aentry_points(group)
	table.sort(actual, function(lhs, rhs)
		return lhs.name < rhs.name
	end)
	return actual
end

describe("Test entry points:", function()
	it("should correctly list all available entry-points in the environment", function()
		---@type EntryPointDef[]
		local EXPECTED = {
			{ name = "ep1", group = "console_scripts", value = { "hello", "entry_point_1" } },
			{ name = "ep2", group = "console_scripts", value = { "hello", "entry_point_2" } },
			{ name = "ep3", group = "my.group", value = { "hello", "ep.entry_point" } },
			{ name = "ep4", group = "my.group", value = { "hello" } },
			{ name = "ep5", group = "console_scripts", value = { "hello", "no_such_function" } },
		}

		assert.same(EXPECTED, aentry_points())
	end)

	it("should list only entry-points with group 'my.group'", function()
		---@type EntryPointDef[]
		local EXPECTED = {
			{ name = "ep3", group = "my.group", value = { "hello", "ep.entry_point" } },
			{ name = "ep4", group = "my.group", value = { "hello" } },
		}

		assert.same(EXPECTED, aentry_points("my.group"))
	end)

	describe("Module location tests - ", function()
		local test_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
		local expected_path = vim.fs.joinpath(test_path, "mock-repo/hello.py")
		local TEST_CASES = {
			{
				input = { name = "ep1", group = "console_scripts", value = { "hello", "entry_point_1" } },
				expected_lineno = 6,
			},
			{
				input = { name = "ep2", group = "console_scripts", value = { "hello", "entry_point_2" } },
				expected_lineno = 14,
			},
			{
				input = { name = "ep3", group = "my.group", value = { "hello", "ep.entry_point" } },
				expected_lineno = 2,
			},
			{
				input = { name = "ep4", group = "my.group", value = { "hello" } },
				expected_lineno = 0,
			},
		}

		for _, case in ipairs(TEST_CASES) do
			it("should find the correct location for `" .. case.input.name .. "`", function()
				local actual_path, lineno = assert(ep.aentry_point_location(case.input))

				assert.same({ expected_path, case.expected_lineno }, { vim.fs.normalize(actual_path), lineno })
			end)
		end

		it("should fail for `ep5`", function()
			local def = {
				name = "ep5",
				group = "console_scripts",
				value = { "hello", "no_such_function" },
			}
			local ok = pcall(ep.aentry_point_location, def)
			assert.are_false(ok)
		end)
	end)
end)
