-- Use the NeoVim runtime to generate a LuaLS rc file.

local rtps = {
	"./lua/?.lua",
	"./lua/?/init.lua",
	"?.lua",
}

-- Add all items in LUA_PATH (if it exists)
local lua_path = os.getenv("LUA_PATH")
if lua_path ~= nil then
	rtps = vim.list_extend(rtps, vim.split(lua_path, ";", { trimempty = true }))
end

-- Add neovim runtime paths (For best reproducability, execute this script with the --clean flag)
local libs = vim.api.nvim_get_runtime_file("", true)

-- Determine busted 'share' path (if busted is available)
if vim.fn.executable("busted") == 1 then
	local result = vim.system({ "luarocks", "config", "deploy_lua_dir" }):wait()
	if result.code == 0 then
		table.insert(libs, vim.trim(result.stdout))
	end
end

local luarc = {
	["$schema"] = "https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json",
	runtime = {
		-- version = "Lua 5.1",
		path = vim.tbl_map(vim.fs.normalize, rtps),
	},
	workspace = {
		library = vim.tbl_map(vim.fs.normalize, libs),
	},
}

io.stdout:write(vim.json.encode(luarc))
