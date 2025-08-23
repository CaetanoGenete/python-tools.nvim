local async = require("python_tools.utils._async")

local M = {}

---@param script string The script to invoke.
---@return fun(python_path: string, ...: string): ...: string
local function make_ascript(script)
	local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
	local path = vim.fs.joinpath(root, script)

	---@async
	---@param python_path string
	return function(python_path, ...)
		local result = async.system({ python_path, path, ... }, { text = true, timeout = 5000 })
		assert(result.code == 0, "Python subprocess failed! " .. result.stderr)
		return result.stdout
	end
end

M.alist_entry_points = make_ascript("list_entry_points.py")
M.afind_entry_point = make_ascript("find_entry_point.py")
M.afind_entry_point_origin = make_ascript("find_entry_point_origin.py")

return M
