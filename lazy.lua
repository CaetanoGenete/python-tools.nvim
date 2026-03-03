return {
	"CaetanoGenete/python-tools.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	build = function()
		require("python_tools").install_library(false, function(msg)
			coroutine.yield(msg)
		end)
	end,
}
