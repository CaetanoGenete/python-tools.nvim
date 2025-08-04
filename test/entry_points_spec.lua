---@module "plenary.test_harness"

local tutils = require("test.utils")

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
		local fixt = tutils.get_fixture("entry_points", "mock_entry_points.json")

		for _, value in ipairs(fixt) do
			value["lineno"] = nil
			value["rel_filepath"] = nil
		end

		assert.same(fixt, aentry_points())
	end)

	it("should list only entry-points with group 'my.group'", function()
		local expected = tutils.get_fixture("entry_points", "mock_entry_points.json")
		expected = vim.fn.filter(expected, function(_, value)
			return value.group == "my.group"
		end)

		for _, value in ipairs(expected) do
			value["lineno"] = nil
			value["rel_filepath"] = nil
		end

		assert.same(expected, aentry_points("my.group"))
	end)

	describe("Module location tests - ", function()
		local fixt = tutils.get_fixture("entry_points", "mock_entry_points.json")
		-- Skip expected failing entries
		fixt = vim.fn.filter(fixt, function(_, value)
			return value.lineno ~= vim.NIL
		end)

		for _, case in ipairs(fixt) do
			it("should find the correct location for `" .. case.name .. "`", function()
				local actual_path, lineno = assert(ep.aentry_point_location(case))
				local expected_path = vim.fs.joinpath(TEST_PATH, case.rel_filepath)

				assert.same({ expected_path, case.lineno }, { vim.fs.normalize(actual_path), lineno })
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
