local joinpath = vim.fs.joinpath
local lazy_path = joinpath(vim.fn.stdpath("data"), "lazy")

vim.opt.rtp:append(joinpath(lazy_path, "plenary.nvim"))
vim.opt.rtp:append(joinpath(lazy_path, "treesitter"))

vim.cmd("runtime! plugin/plenary.vim")
require("nvim-treesitter").setup()

-- vim.cmd("TSInstallSync! python")

if vim.fn.has("win32") == 1 then
	vim.g.python = "./test/mock-repo/.venv/Scripts/python.exe"
else
	vim.g.python = "./test/mock-repo/.venv/bin/python"
end
