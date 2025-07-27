---@module "plenary.test_harness"

local ep = require("python_tools.entry_points")

local function aentrypoints(group)
	local actual = ep.aentrypoints(group)
	table.sort(actual, function(lhs, rhs)
		return lhs.name < rhs.name
	end)
	return actual
end

describe("Test entry points:", function()
	it("should correctly list all available entry-points in the environment", function()
		---@type EntryPointDef[]
		local expected = {
			{ name = "ep1", group = "console_scripts", value = { "hello", "entry_point_1" } },
			{ name = "ep2", group = "console_scripts", value = { "hello", "entry_point_2" } },
			{ name = "ep3", group = "my.group", value = { "hello", "ep.entry_point" } },
			{ name = "ep4", group = "my.group", value = { "hello" } },
			{ name = "ep5", group = "console_scripts", value = { "hello", "no_such_function" } },
		}

		assert.same(expected, aentrypoints())
	end)

	it("should list only entry-points with group 'my.group'", function()
		---@type EntryPointDef[]
		local expected = {
			{ name = "ep3", group = "my.group", value = { "hello", "ep.entry_point" } },
			{ name = "ep4", group = "my.group", value = { "hello" } },
		}

		assert.same(expected, aentrypoints("my.group"))
	end)
end)
