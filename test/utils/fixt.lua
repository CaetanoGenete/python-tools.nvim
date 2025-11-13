local M = {}

local fixture_cache = {}

--- Returns path relative to 'fixture path' for this test suite. Additional arguments will be
--- concatenated using `vim.fs.joinpath`
---
---@vararg string
---@return string
function M.path(...)
	return vim.fs.normalize(vim.fs.abspath(vim.fs.joinpath("test/fixtures/", ...)))
end

--- Reads file relative to fixture directory.
---
--- If extension ends with .json, the contents will be deserialised into a lua table.
---
--- Subsequent calls with the same paths will be cached.
---
---@vararg string path segments to file, will be concated using `vim.fs.joinpath`.
---@return any
function M.get(...)
	local fixture_path = M.path(...)

	local cached = fixture_cache[fixture_path]
	if not cached then
		local file = assert(io.open(fixture_path, "rb"))

		local ok, fixture = pcall(file.read, file, "a")
		io.close(file)

		if not ok then
			error(fixture)
		end

		if vim.endswith(fixture_path, ".json") then
			fixture = vim.json.decode(fixture)
		end

		fixture_cache[fixture_path] = fixture
		cached = fixture
	end

	return vim.deepcopy(cached)
end

function M.clear_fixture_cache()
	fixture_cache = {}
end

return M
