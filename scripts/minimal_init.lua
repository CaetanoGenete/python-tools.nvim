local joinpath = vim.fs.joinpath

local plugin_path = os.getenv("TEST_PLUGIN_PATH")
if not plugin_path then
	-- Default to lazy default install path
	plugin_path = joinpath(vim.fn.stdpath("data"), "lazy")
end
plugin_path = vim.fn.expand(plugin_path)
vim.print("Resolved plugin path to: " .. plugin_path)

local plugins = {
	"plenary.nvim",
	"telescope.nvim",
	"treesitter",
}
for _, plugin in ipairs(plugins) do
	vim.opt.rtp:append(joinpath(plugin_path, plugin))
end

vim.cmd("runtime! plugin/plenary.vim")
require("nvim-treesitter").setup()

if not require("nvim-treesitter.parsers").has_parser("python") then
	vim.cmd("TSInstallSync! python")
end

if vim.fn.has("win32") == 1 then
	vim.g.pytools_default_python_path = "./test/fixtures/mock-repo/.venv/Scripts/python.exe"
else
	vim.g.pytools_default_python_path = "./test/fixtures/mock-repo/.venv/bin/python"
end

-- Prevent messing up local SHADA during tests
vim.opt.shadafile = "NONE"
