local M = {}

function M.setup()
	local root = vim.fs.dirname(debug.getinfo(1).source) .. "/../../../"
	root = vim.fs.normalize(vim.fs.abspath(root))

	-- Setup package path to be able to find c libraries
	package.cpath = package.cpath
		.. ";"
		.. vim.fs.joinpath(root, "lib/?.dll")
		.. ";"
		.. vim.fs.joinpath(root, "lib/?.so")
		.. ";"
end

return M
