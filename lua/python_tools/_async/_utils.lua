---@class _transform
local M = {}

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

-- Bad things seem to happen if the coroutine is resumed during fast events.
local safe_resume = vim.schedule_wrap(coroutine.resume)

---@nodiscard
function M.wrap(callback_fn, exp_args)
	---@async
	local function async_fn(...)
		local nargs = select("#", ...)
		if exp_args ~= nargs then
			error(("This function only accepts `%s` but `%s` passed!"):format(exp_args, nargs))
		end

		local coro = assert(coroutine.running(), "Async function called outside of coroutine!")

		local callback_completed = false
		local callback_ret = nil

		local forward_args = { ... }
		table.insert(forward_args, function(...)
			callback_completed = true
			callback_ret = { ... }

			if coroutine.status(coro) == "suspended" then
				safe_resume(coro)
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

return M
