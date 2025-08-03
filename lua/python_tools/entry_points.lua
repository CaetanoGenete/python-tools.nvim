local async = require("python_tools.utils._async")
local pyutils = require("python_tools.utils.python")

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

local M = {}

---@param script string The script to invoke.
---@return fun(python_path: string, ...: string): ...: string
local function make_ascript(script)
	local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
	local path = vim.fs.joinpath(root, "scripts", script)

	---@async
	---@param python_path string
	return function(python_path, ...)
		local result = async.system({ python_path, path, ... }, { text = true, timeout = 5000 })
		assert(result.code == 0, "Python subprocess failed! " .. result.stderr)
		return result.stdout
	end
end

local alist_entry_points = make_ascript("list_entry_points.py")
local afind_entry_point = make_ascript("find_entry_point.py")
local afind_entry_point_origin = make_ascript("find_entry_point_origin.py")

---@class EntryPointDef
---@field name string
---@field group string
---@field value string[]

---Returns entry-points available in the environment.
---@async
---@param group string? If non-nil, only selects entry-points in this group.
---@param python_path string? Path to python binary. Defaults to binary on PATH.
---@return EntryPointDef[]
function M.aentry_points(group, python_path)
	python_path = pyutils.default_path(python_path)

	local args = {}
	if group ~= nil then
		args = { group }
	end

	local result = alist_entry_points(python_path, unpack(args))
	return vim.json.decode(result)
end

local ROOT_ATTR_QUERY = [[
	(module
		[
			(function_definition
				name: (_) @entry_point_name)
		  (expression_statement
				(assignment
					left: (_) @entry_point_name))
		]
		(#eq? @entry_point_name "%s")
	)
]]

---Uses treesitter to find entry-point location in source code.
---
---For simple *entry-points*, it should be more accurate.
---@async
---@param python_path string
---@param module string
---@param attr string?
---@return string, integer
local function aentry_point_location_ts(python_path, module, attr)
	if attr == nil or attr:find(".", nil, true) then
		error("TS implementation can only be used with module attributes, use importlib instead.")
	end

	-- It's still necessary to use importlib to map the module path to a system
	-- path (where possible). However, this does less module loading and
	-- dependency resolution than loading the entry-point.
	local file_path = afind_entry_point_origin(python_path, module)
	file_path = vim.fs.normalize(file_path)

	local lnum = 0

	-- If `attr` is None, then presumably entry-point invokes module.
	if attr then
		local file_content = assert(async.read_file(file_path))

		local ts_query = string.format(ROOT_ATTR_QUERY, attr)
		local parsed_ts_query = vim.treesitter.query.parse("python", ts_query)

		local parser = vim.treesitter.get_string_parser(file_content, "python")
		local root = parser:parse()[1]:root()

		local last_match = -1
		for _, node in parsed_ts_query:iter_captures(root, file_content) do
			local row = node:range()
			last_match = math.max(last_match, row + 1)
		end

		assert(last_match ~= -1, "Could not find a match!")
		lnum = last_match
	end

	return file_path, lnum
end

---@class EntryPoint
---@field name string
---@field group string
---@field filename string
---@field lineno integer

---Returns entry-point location using importlib.
---@async
---@param python_path string
---@param name string
---@param group string
---@return EntryPoint
local function aentry_point_location_importlib(python_path, name, group)
	local result = afind_entry_point(python_path, name, group)
	return vim.json.decode(result)
end

---Find entry-point definition in source.
---@async
---@param def EntryPointDef
---@param python_path string? Path to python binary. Defaults to binary on PATH.
---@return string? path, integer lineno
function M.aentry_point_location(def, python_path)
	python_path = pyutils.default_path(python_path)

	-- Try to use tree-sitter implementation first, then fallback to importlib
	-- upon failure.
	--
	-- There are a few reasons for this:
	--
	-- 1. importlib can fail despite the entry-point being valid. If, for
	--    example, a dependency is not available, importlib will fail without
	--    returning the location of the entry-point.
	--
	-- 2. importlib will not return the exact location of an entry-point if it is
	--    not a function. Take for example `ep = main`, where `main` is a function.
	--    With the current importlib implementation, if `ep` is defined as the
	--    entry-point, the location will resolve to the definition of `main`.
	--
	-- None of these issues appear when fetching the entry-point using
	-- tree-sitter, as no dependency resolution occurs. However, it cannot follow
	-- chains of attributes, such as `a.b.c`.
	local ok, result, loc = pcall(aentry_point_location_ts, python_path, unpack(def.value))
	if ok then
		return result, loc
	end

	local ep = aentry_point_location_importlib(python_path, def.name, def.group)
	return ep.filename, ep.lineno
end

return M
