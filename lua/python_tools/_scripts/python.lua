local async = require("python_tools._async")

local M = {}

---@generic T
---@nodiscard
---@param script string The script to invoke.
---@param map_fn fun(result: string): T Maps stdout of the process.
---@param err_map table<integer, string> Maps the exit codes to error messages.
---@return fun(python_path: string, args: (string|nil)[]): ...: T?,string?
local function make_ascript(script, map_fn, err_map)
	local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
	local path = vim.fs.joinpath(root, script)

	---@async
	---@param python_path string
	return function(python_path, user_args)
		local args = { python_path, path }
		for _, arg in ipairs(user_args) do
			if arg ~= nil then
				table.insert(args, arg)
			end
		end

		local result = async.system(args, { text = true, timeout = 5000 })
		if result.code ~= 0 then
			return nil, err_map[result.code]
		end
		return map_fn(result.stdout), nil
	end
end

M.alist_entry_points_importlib = make_ascript("list_entry_points_importlib.py", vim.json.decode, {
	[1] = "Unexpected failure!",
	[2] = "Could not import module `importlib`, please ensure it's installed.",
	[3] = "Listing entrypoints requires python version >=3.8, please update!",
})

M.alist_entry_points_setuppy = make_ascript("list_entry_points_setuppy.py", vim.json.decode, {
	[1] = "Unexpected failure!",
	[2] = "Could not import module `importlib`, please ensure it's installed.",
	[3] = "Failed to load `setup.py` module!",
	[4] = "Failed to load `setup.py` module!",
	[5] = "Failed to execute `setup.py` file!",
	[6] = "Listing entrypoints requires python version >=3.8, please update!",
})

M.afind_entry_point_importlib = make_ascript("find_entry_point_importlib.py", vim.json.decode, {
	[1] = "Unexpected failure!",
	[2] = "Could not import module `importlib`, please ensure it's installed.",
	[3] = "Could not find entrypoint!",
	[4] = "Failed to file containing entrypoint!",
	[5] = "Failed to line number of entrypoint object!",
	[6] = "Finding entrypoints requires python version >=3.8, please update!",
})

M.afind_entry_point_origin_importlib =
	make_ascript("find_entry_point_origin_importlib.py", vim.fs.normalize, {
		[1] = "Unexpected failure!",
		[2] = "Could not import module `importlib`, please ensure it's installed.",
		[3] = "Could not find entrypoint origin.",
	})

return M
