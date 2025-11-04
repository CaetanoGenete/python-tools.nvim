vim.treesitter.language.add("python", { path = "./misc/python.so" })

if vim.fn.has("win32") == 1 then
	vim.g.pytools_default_python_path = "./test/fixtures/mock-repo/.venv/Scripts/python.exe"
else
	vim.g.pytools_default_python_path = "./test/fixtures/mock-repo/.venv/bin/python"
end

-- Prevent messing up local SHADA during tests
vim.opt.shadafile = "NONE"
