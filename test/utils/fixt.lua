local M = {}

local fixture_cache = {}

--- Returns path relative to 'fixture path' for this test suite. Additional arguments will be
--- concatenated using `vim.fs.joinpath`
---
---@vararg string
---@return string
function M.path(...)
	return vim.fs.abspath(vim.fs.joinpath("test/fixtures/", ...))
end

---@vararg string
---@return table<any, any>
function M.get(...)
	local fixture_path = M.path(...)

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

return M
