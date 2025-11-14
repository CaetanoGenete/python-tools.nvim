---@diagnostic disable: lowercase-global

rockspec_format = "3.0"
package = "python-tools.nvim"
version = "0.2-0"
source = {
	url = "git+https://https://github.com/CaetanoGenete/python-tools.nvim",
}
dependencies = {
	"lua>=5.1",
}
test_dependencies = {
	"telescope.nvim==0.1.9-1",
}
build = {
	type = "builtin",
	copy_directories = {},
}
