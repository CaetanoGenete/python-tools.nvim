---@diagnostic disable: lowercase-global

rockspec_format = "3.0"
package = "python-tools.nvim"
version = "scm-1"
source = {
	url = "git+https://https://github.com/CaetanoGenete/python-tools.nvim",
}
dependencies = {
	"lua==5.1",
}
test_dependencies = {
	"telescope.nvim==0.1.9-1",
}
build = {
	type = "builtin",
	modules = {
		["python_tools.meta._pyproject"] = { "./src/pyproject.c", "./src/tomlc17.c" },
	},
}
