local M = {}

--- Gets the default python binary path.
---
--- The path is resolved to be the first not-nil from:
---  - `vim.g.pytools_default_python_path`
---  - `"python"`
---@return string
function M.default_path()
	return vim.g.pytools_default_python_path or "python"
end

return M
