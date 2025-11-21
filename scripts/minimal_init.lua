if vim.version.lt(vim.version(), { 0, 11, 0 }) then
	error("Only supporting Neovim version >= 0.11, please update.")
end

-- Useful when manually testing, allows 'nvim -u ./scripts/minimal_init.lua' to pickup plugin.
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local py_parser_path
local python_path

if vim.fn.has("win32") == 1 then
	python_path = "./test/fixtures/mock-repo/.venv/Scripts/python.exe"
	py_parser_path = "./build-ts/install/bin/tree-sitter-python.dll"
else
	python_path = "./test/fixtures/mock-repo/.venv/bin/python"
	py_parser_path = "./build-ts/install/lib/libtree-sitter-python.so"
end

vim.g.pytools_default_python_path = python_path

-- Prevent the CI from logging errors, this is not an error by itself.
local ok = pcall(vim.treesitter.language.add, "python", { path = py_parser_path })
if not ok then
	print("Could not load TS parser for python!")
end

require("python_tools").setup()

-- Prevent messing up local SHADA during tests
vim.opt.shadafile = "NONE"
