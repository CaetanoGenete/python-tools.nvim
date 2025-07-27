-- Use the NeoVim runtime to generate a LuaLS rc file.

local luarc = {
	runtime = {
		version = "Lua 5.4",
	},
	workspace = {
		library = vim.api.nvim_get_runtime_file("", true),
	},
}

io.stdout:write(vim.json.encode(luarc))
