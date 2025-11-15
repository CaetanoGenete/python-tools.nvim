---@meta

---@class pytools
local capi = {}

--- Fetches entry-points from the pyproject.toml pointed at by `file`.
---
---@nodiscard
---@param file file*
---@return EntryPointDef[]
function capi.entry_points_from_pyproject(file) end

return capi
