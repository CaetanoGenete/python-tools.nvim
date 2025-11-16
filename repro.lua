vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

require("lazy.minit").repro({
	spec = {
		{
			"CaetanoGenete/python-tools.nvim",
			submodules = false,
			config = true,
		},
		{
			"nvim-treesitter/nvim-treesitter",
			name = "treesitter",
			main = "nvim-treesitter.configs",
			opts = {
				ensure_installed = { "python" },
			},
		},
	},
})
