---@meta

---@class pyproject
local capi = {}

--- Fetches entry-points from the pyproject.toml pointed at by `file`.
---
---@nodiscard
---@param src string
---@return EntryPointDef[]
function capi.entry_points(src) end

return capi
