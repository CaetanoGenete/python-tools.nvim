---@module "plenary.test_harness"

local tutils = require("test.utils")

local ep = require("python_tools.meta.entry_points")

---@param entry_points EntryPointDef[]
local function sort_entry_points(entry_points)
	table.sort(entry_points, function(lhs, rhs)
		return lhs.name < rhs.name
	end)
end

describe("aentry_points tests:", function()
	it("should correctly list all available entry-points in the environment", function()
		local fixt = tutils.get_fixture("entry_points", "mock_entry_points.json")
		local actual = ep.aentry_points()
		sort_entry_points(actual)

		for _, value in ipairs(fixt) do
			value["lineno"] = nil
			value["rel_filepath"] = nil
		end

		assert.same(fixt, actual)
	end)

	it("should list only entry-points with group 'my.group'", function()
		local actual = assert(ep.aentry_points("my.group"))
		sort_entry_points(actual)

		local expected = tutils.get_fixture("entry_points", "mock_entry_points.json")
		expected = vim.fn.filter(expected, function(_, value)
			return value.group == "my.group"
		end)

		for _, value in ipairs(expected) do
			value["lineno"] = nil
			value["rel_filepath"] = nil
		end

		assert.same(expected, actual)
	end)
end)

describe("aentry_points_from_project tests:", function()
	it("should correctly list all available entry_points from mock-setup-py-repo", function()
		local fixt = tutils.get_fixture("entry_points", "mock_setup_py_entry_points.json")
		local eps =
			assert(ep.aentry_points_from_project(vim.fs.joinpath(TEST_PATH, "mock-setup-py-repo")))
		sort_entry_points(eps)

		for _, value in ipairs(fixt) do
			value["lineno"] = nil
			value["rel_filepath"] = nil
		end

		assert.same(fixt, eps)
	end)
end)

describe("aentry_point_location tests:", function()
	local fixt = tutils.get_fixture("entry_points", "mock_entry_points.json")
	-- Skip expected failing entries
	fixt = vim.fn.filter(fixt, function(_, value)
		return value.lineno ~= vim.NIL
	end)

	for _, case in ipairs(fixt) do
		it("should find the correct location for `" .. case.name .. "`", function()
			local actual, errmsg = ep.aentry_point_location(case)
			assert(actual, errmsg)
			local expected_path = vim.fs.joinpath(TEST_PATH, case.rel_filepath)

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

		local result, err = ep.aentry_point_location(def)
		assert.is_nil(result)
		assert.no.is_nil(err)
	end)
end)
