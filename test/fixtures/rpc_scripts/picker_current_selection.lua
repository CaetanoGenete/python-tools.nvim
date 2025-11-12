---@type EntryPointEntry
local result = require("telescope.actions.state").get_selected_entry()
if result == nil then
	return nil
end

--- Deep copy value, except types which are not serialisable.
---@generic T
---@param value T
---@return T?
local function copy_serialisable(value)
	local tvalue = type(value)

	if tvalue == "table" then
		local new_tbl = {}
		for k, v in pairs(value) do
			new_tbl[k] = copy_serialisable(v)
		end
		return new_tbl
	end

	if tvalue == "userdata" or tvalue == "function" or tvalue == "thread" then
		return nil
	end

	return value
end

return copy_serialisable(result)
