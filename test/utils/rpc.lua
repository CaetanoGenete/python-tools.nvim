local fixt = require("test.utils.fixt")

local M = {}

--- Executes `filepath` on remote Neovim server.
---
---@param channel integer Neovim process.
---@param filepath string Path to Lua file to execute. This is relative to the 'rpc_scripts' fixture
--- directory.
---@vararg any Args to pass to lua file.
---@return any
function M.exec_lua(channel, filepath, ...)
	local file = io.open(fixt.path("rpc_scripts", filepath))
	if file == nil then
		error("Could not open script file: " .. file)
	end

	local ok_read, contents = pcall(file.read, file, "a")
	if not ok_read then
		io.close(file)
		error("Failed to read file!")
	end

	local ok_call, result = pcall(vim.rpcrequest, channel, "nvim_exec_lua", contents, { ... })
	if not ok_call then
		io.close(file)
		error("Failed to make RPC request!")
	end

	return result
end

return M
