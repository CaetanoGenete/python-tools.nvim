local plenary_path = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "plenary.nvim")

vim.opt.rtp:append(plenary_path)

vim.cmd("runtime! plugin/plenary.vim")

if vim.fn.has("win32") == 1 then
	vim.g.python = "./test/mock-repo/.venv/Scripts/python.exe"
else
	vim.g.python = "./test/mock-repo/.venv/bin/python"
end
