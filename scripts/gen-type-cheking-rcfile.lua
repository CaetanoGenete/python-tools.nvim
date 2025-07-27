-- Use the NeoVim runtime to generate a LuaLS rc file.

local luarc = {
	runtime = {
		version = "LuaJIT 2.1",
	},
	workspace = {
		library = vim.api.nvim_get_runtime_file("", true),
	},
}

io.stdout:write(vim.json.encode(luarc))
