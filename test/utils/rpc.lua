local fixt = require("test.utils.fixt")

local M = {}

--- Executes Lua script at `filepath` on remote Neovim server.
---
---@param channel integer Neovim process.
---@param filepath string Path to Lua file to execute. This is relative to the 'rpc_scripts' fixture
--- directory.
---@vararg any Args to pass to lua file.
---@return any
function M.exec_lua(channel, filepath, ...)
	local script = fixt.get("rpc_scripts", filepath)
	return vim.rpcrequest(channel, "nvim_exec_lua", script, { ... })
end

return M
