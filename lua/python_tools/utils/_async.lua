local M = {}

local wrap = function(callback_fn, exp_args)
	---@async
	local function async_fn(...)
		local nargs = select("#", ...)

		if exp_args ~= nargs then
			error("This function only accepts `" .. exp_args .. "` but `" .. nargs .. "` passed!")
		end

		local coro = assert(coroutine.running(), "Async function called outside of coroutine!")

		local callback_completed = false
		local callback_ret = nil

		local forward_args = { ... }
		table.insert(forward_args, function(...)
			callback_completed = true
			callback_ret = { ... }

			if coroutine.status(coro) == "suspended" then
				coroutine.resume(coro)
			end
		end)

		callback_fn(unpack(forward_args))

		if not callback_completed then
			-- If we are here, then callback must not have been called yet, so it
			-- will do so asynchronously. Yield control and wait for the callback to
			-- resume it.
			coroutine.yield()
		end
		return unpack(callback_ret or {})
	end

	return async_fn
end

---@async
---@type fun(cmd:string[], opts:vim.SystemOpts): vim.SystemCompleted
M.system = wrap(vim.system, 2)

---@async
---@type fun(path:string, flags:string|integer, mode:integer):string?,integer?
M.fs_open = wrap(vim.uv.fs_open, 3)

---@async
---@type fun(fd:integer):string?,integer?
M.fs_close = wrap(vim.uv.fs_close, 3)

---@async
---@type fun(fd:integer, size:integer, offset:integer?):string?,string?
M.fs_read = wrap(vim.uv.fs_read, 3)

---@class UVStat
---@field dev integer
---@field mode integer
---@field nlink integer
---@field uid integer
---@field gid integer
---@field rdev integer
---@field ino integer
---@field size integer
---@field blksize integer
---@field blocks integer
---@field flags integer
---@field gen integer
---@field type string

---@async
---@type fun(fd: integer):string?,UVStat?
M.fs_stat = wrap(vim.uv.fs_fstat, 1)

---@async
---@type fun(timer, interval: integer, repeat: integer)
local timer_start = wrap(vim.uv.timer_start, 3)

---Pause execution for `duration` milliseconds.
---@param duration integer in milliseconds.
M.sleep = function(duration)
	local timer = vim.uv.new_timer()
	timer_start(timer, duration, 0)
	timer:stop()
	timer:close()
end

---Executes an async function.
---@param async_function fun(...): ...
M.run = function(async_function, ...)
	coroutine.resume(coroutine.create(async_function), ...)
end

---Schedules an async function for execution.
---
---When the function completes it will invoke `callback` on NeoVim's main
---event-loop.
---@generic R
---@param async_function fun(...): R Async function to be scheduleded.
---@param callback fun(success: boolean, result: R?) Callback to be executed upon completion.
---@param ... any Additional arguments to be passed to `async_function`
M.run_callback = function(async_function, callback, ...)
	M.run(function(...)
		local ok, result = pcall(async_function, ...)
		vim.schedule_wrap(callback)(ok, result)
	end, ...)
end

---Returns the contents of the file at `path`.
---@async
---@param path string
---@return string? content, string? errmsg
M.read_file = function(path)
	local open_err, fd = M.fs_open(path, "r", 438)
	if open_err or fd == nil then
		return nil, open_err
	end

	local stat_err, stat = M.fs_stat(fd)
	if stat_err or stat == nil then
		M.fs_close(fd)
		return nil, stat_err
	end

	local read_err, data = M.fs_read(fd, stat.size, 0)
	if read_err or data == nil then
		M.fs_close(fd)
		return nil, read_err
	end

	return data, nil
end

return M
