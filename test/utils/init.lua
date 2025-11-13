local M = {}

local ASYNC_TEST_TIMEOUT_MS = 5000
local ASYNC_TEST_INTERVAL_MS = 20

--- Helper function for writting async tests.
---
--- Example usage:
--- ```lua
--- async(it, "should test", function()
---		assert(10 == 11, "That's not quite right...")
--- end)
--- ```
---
---@generic T
---@param it fun(name: string, fn: fun()) busted `it` callable.
---@param name string The name of the test.
---@param callable fun(): T?
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

		vim.wait(ASYNC_TEST_TIMEOUT_MS, function()
			return status ~= "pending"
		end, ASYNC_TEST_INTERVAL_MS)

		if status == "pending" then
			error("Timeout!")
		end

		if status == "error" then
			error(err)
		end
	end)
end

---@param value any
---@param curr_indent integer
---@param indent integer
---@return string
local function _pretty_format(value, curr_indent, indent)
	if type(value) == "string" then
		return ('"%s"'):format(value)
	end

	if type(value) ~= "table" then
		return value
	end

	local result = "{\n"
	local indent_str = (" "):rep(curr_indent + indent)

	for k, v in pairs(value) do
		if type(k) == "string" then
			k = ('"%s"'):format(k)
		end

		result = ("%s%s[%s] = %s,\n"):format(
			result,
			indent_str,
			tostring(k),
			tostring(_pretty_format(v, curr_indent + indent, indent))
		)
	end
	result = ("%s%s}"):format(result, (" "):rep(curr_indent))

	return result
end

--- Pretty formats table.
---
--- If `value` is not a table, this function acts like the identity.
---
---@param value any
---@param indent integer?
---@return string
local function pretty_format(value, indent)
	if type(value) ~= "table" then
		return value
	end

	return _pretty_format(value, 0, indent or 2)
end

--- Logs the provided message `message`, with printf style format args. Any tables will be pretty
--- printed.
---
---@param message string
---@vararg any
function M.log(message, ...)
	local args = {}

	for _, value in pairs({ ... }) do
		table.insert(args, pretty_format(value))
	end

	print(("[test-log] %s"):format(message:format(table.unpack(args))))
end

--- Returns a shallow copy of `tbl`, with only the keys in `fields`.
---
---@generic T
---@generic U
---@param tbl table<T, U>
---@param fields T[]
---@return table<T, U>
function M.tbl_subset(tbl, fields)
	local result = {}
	for _, field in ipairs(fields) do
		result[field] = tbl[field]
	end
	return result
end

M.fixt = require("test.utils.fixt")
M.rpc = require("test.utils.rpc")

return M
