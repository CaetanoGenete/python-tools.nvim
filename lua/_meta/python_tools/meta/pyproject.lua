---@meta

---@class pyproject
local capi = {}

--- Fetches entry-points from the pyproject.toml pointed at by `file`.
---
---@nodiscard
---@param src string
---@param group string?
---@return EntryPointDef[]? eps, string? errmsg
function capi.entry_points(src, group) end

return capi
