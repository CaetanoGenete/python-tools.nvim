local async = require("python_tools._async")

local M = {}

---@generic T
---@nodiscard
---@param script string The script to invoke.
---@param map_fn fun(result: string): T
---@return fun(python_path: string, args: (string|nil)[]): ...: T?,integer
local function make_ascript(script, map_fn)
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
			return nil, result.code
		end
		return map_fn(result.stdout), result.code
	end
end

M.alist_entry_points_importlib = make_ascript("list_entry_points.py", vim.json.decode)
M.afind_entry_point_importlib = make_ascript("find_entry_point.py", vim.json.decode)
M.afind_entry_point_origin_importlib = make_ascript("find_entry_point_origin.py", vim.fs.normalize)

return M
