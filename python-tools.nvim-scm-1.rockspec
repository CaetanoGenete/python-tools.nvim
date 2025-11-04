---@diagnostic disable: lowercase-global

rockspec_format = "3.0"
package = "python-tools.nvim"
version = "scm-1"
source = {
	url = "git+https://https://github.com/CaetanoGenete/python-tools.nvim",
}
dependencies = {
	"telescope.nvim",
}
build = {
	type = "builtin",
	copy_directories = {},
}
