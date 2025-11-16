---@meta

---@class pyproject
local capi = {}

--- Fetches entry-points from the pyproject.toml file `content`.
---
--- Note: this is a c library binding. See {project-root}/src/pyproject.c.
---
---@nodiscard
---@param content string
---@param group string?
---@return EntryPointDef[]? eps, string? errmsg
function capi.entry_points(content, group) end

return capi
