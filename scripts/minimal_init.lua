if vim.version.lt(vim.version(), { 0, 11, 0 }) then
	error("Only supporting Neovim version >= 0.11, please update.")
end

-- Useful when manually testing, allows 'nvim -u ./scripts/minimal_init.lua' to pickup plugin.
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local py_parser_path
if vim.fn.has("win32") == 1 then
	py_parser_path = "./build-ts/install/bin/tree-sitter-python.dll"
else
	py_parser_path = "./build-ts/install/lib/libtree-sitter-python.so"
end

-- Prevent the CI from logging errors, this is not an error by itself.
local ok = pcall(vim.treesitter.language.add, "python", { path = py_parser_path })
if not ok then
	print("Could not load TS parser for python!")
end

local install_clib = true
if os.getenv("PYTOOLS_NO_INSTALL_CLIB") then
	install_clib = false
end

require("python_tools").setup({
	install_clib = install_clib,
})

-- Prevent messing up local SHADA during tests
vim.opt.shadafile = "NONE"
