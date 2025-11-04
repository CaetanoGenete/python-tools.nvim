-- IMPORTANT: this module MUST be at the root of the `/test` directory!

--- Full path to the `/test` directory.
TEST_PATH = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")

local M = {}

local fixture_cache = {}

---@vararg string
---@return table<any, any>
function M.get_fixture(...)
	local fixture_path = vim.fs.joinpath(TEST_PATH, "fixtures", ...)

	local cached = fixture_cache[fixture_path]
	if not cached then
		local fixture_file = assert(io.open(fixture_path, "rb"))
		local fixture = vim.json.decode(fixture_file:read("all"))

		fixture_cache[fixture_path] = fixture
		cached = fixture
	end

	return vim.deepcopy(cached)
end

function M.clear_fixture_cache()
	fixture_cache = {}
end

function M.async(it, name, callable)
	it(name, function()
		local status = "pending"
		local err = nil

		require("python_tools._async").run_callback(callable, function(success, result)
			if not success then
				err = result
				status = "error"
			else
				status = "complete"
			end
		end)

		vim.wait(5000, function()
			return status ~= "pending"
		end, 20)

		if status == "pending" then
			error("Timeout!")
		end

		if status == "error" then
			error(err)
		end
	end)
end

return M
