---@diagnostic disable: lowercase-global

package = "python-tools.nvim"
version = "0.2-0"
source = {
	url = "git+https://https://github.com/CaetanoGenete/python-tools.nvim",
}
dependencies = {
	"lua>=5.1",
	"telescope.nvim",
}
build = {
	type = "builtin",
	copy_directories = {},
}
