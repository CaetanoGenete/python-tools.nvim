local action_state = require("telescope.actions.state")
local buf = vim.api.nvim_get_current_buf()
local results = action_state.get_current_picker(buf).finder.results

--- Deep copy value, except types which are not serialisable.
---@generic T
---@param value T
---@return T?
local function deepcopy_serialisable(value)
	local tvalue = type(value)

	if tvalue == "table" then
		local new_tbl = {}
		for k, v in pairs(value) do
			new_tbl[k] = deepcopy_serialisable(v)
		end
		return new_tbl
	end

	if tvalue == "userdata" or tvalue == "function" or tvalue == "thread" then
		return nil
	end

	return value
end

return vim.tbl_map(deepcopy_serialisable, results)
