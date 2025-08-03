local M = {}

---Gets the default python binary path.
---
---The path is resolved to be the first not-nil from:
--- - `override`
--- - `vim.g.pytools_default_python_path`
--- - `"python"`
---
---`override` is purely for syntactic purposes, so as to allow:
---```lua
---local python_path = ...
---python_path = utils.default_path(python_path)
---```
---@param override string? If not `nil`, this is returned instead.
---@return string
function M.default_path(override)
	return override or vim.g.pytools_default_python_path or "python"
end

return M
