local M = {}

---@param nodes TSNode[]
---@param content string
function M.bounding_text(nodes, content)
	local lb = #content + 1
	local ub = 0
	for _, node in ipairs(nodes) do
		local _, _, node_start, _, _, node_end = node:range(true)
		lb = math.min(lb, node_start)
		ub = math.max(ub, node_end)
	end

	if ub <= lb then
		return ""
	end
	return content:sub(lb + 1, ub)
end

return M
