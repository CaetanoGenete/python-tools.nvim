local py_parser_path

if vim.fn.has("win32") == 1 then
	vim.g.pytools_default_python_path = "./test/fixtures/mock-repo/.venv/Scripts/python.exe"
	py_parser_path = "./build-ts/install/bin/tree-sitter-python.dll"
else
	vim.g.pytools_default_python_path = "./test/fixtures/mock-repo/.venv/bin/python"
	py_parser_path = "./build-ts/install/lib/libtree-sitter-python.so"
end

vim.treesitter.language.add("python", { path = py_parser_path })

-- Prevent messing up local SHADA during tests
vim.opt.shadafile = "NONE"
