---@class _async
local M = {
	uv = require("python_tools._async.uv"),
}

--- Executes an async function.
---
---@param async_function fun(...): ...:any
function M.run(async_function, ...)
	coroutine.resume(coroutine.create(async_function), ...)
end

--- Schedules an async function for execution.
---
--- When the function completes it will invoke `callback`.
---
---@generic R
---@param async_function fun(...): R Async function to be scheduleded.
---@param callback fun(success: boolean, result: R?) Callback to be executed upon completion.
---@param ... any Additional arguments to be passed to `async_function`
function M.run_callback(async_function, callback, ...)
	M.run(function(...)
		callback(pcall(async_function, ...))
	end, ...)
end

local wrap = require("python_tools._async._utils").wrap

---@async
---@type fun(cmd:string[], opts:vim.SystemOpts): vim.SystemCompleted
M.system = wrap(vim.system, 2)

--- Pause execution for `duration` milliseconds.
---
---@async
---@param duration integer in milliseconds.
function M.sleep(duration)
	---@diagnostic disable-next-line: undefined-field
	local timer = vim.uv.new_timer()
	M.uv.timer_start(timer, duration, 0)

	timer:stop()
	timer:close()
end

--- Returns the contents of the file at `path`.
---
---@async
---@nodiscard
---@param path string
---@return string? content, string? errmsg
function M.read_file(path)
	local open_err, fd = M.uv.fs_open(path, "r", 438)
	if open_err or fd == nil then
		return nil, open_err
	end

	local stat_err, stat = M.uv.fs_fstat(fd)
	if stat_err or stat == nil then
		M.uv.fs_close(fd)
		return nil, stat_err
	end

	local read_err, data = M.uv.fs_read(fd, stat.size, 0)
	if read_err or data == nil then
		M.uv.fs_close(fd)
		return nil, read_err
	end

	return data, nil
end

--- Searches current and all parent directories for `file`.
---
---@async
---@nodiscard
---@param path string the directory wherein to start the search. Will be normalized by
--- `vim.fs.normalize` first.
---@param search string|string[] The basename to search for. If a list is provided, the first match
--- will be returned.
---@return string? path, string? errmsg There are two cases:
--- - failure -> `errmsg` will be non-`nil`. NOTE: failure to find file is **not** an error.
--- - success -> normalized path of the first match, or `nil`
function M.findfile(path, search)
	path = vim.fs.normalize(path)

	if type(search) == "string" then
		search = { search }
	end

	local curr = path
	repeat
		for _, name in ipairs(search) do
			local candidate = vim.fs.joinpath(curr, name)
			local stat_err = M.uv.fs_stat(candidate)
			if not stat_err then
				return candidate, nil
			end
		end

		local last = curr
		curr = vim.fs.dirname(curr)
	until last == curr

	return nil, "Could not find any of {" .. vim.fn.join(search, ", ") .. "} from " .. path
end

return M
