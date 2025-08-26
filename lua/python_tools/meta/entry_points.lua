local async = require("python_tools.utils._async")
local pyutils = require("python_tools.utils.python")
local pyscripts = require("python_tools._scripts.python")
local tsutils = require("python_tools.utils._treesitter")

local M = {}

---@class EntryPointDef
---@field name string
---@field group string
---@field value string[]

local SETUP_PY_EP_QUERY = vim.treesitter.query.parse(
	"python",
	[[
	(call
		function: (_) @function.name (#eq? @function.name "setup")
		arguments: (argument_list
			(keyword_argument
				name: (_) @function.arg (#eq? @function.arg "entry_points")
				value: (dictionary
					(pair
						key: (string
							(string_content) @entrypoint.group)
						value: (list
							(string
								(string_content) @entrypoint.entry)))))))
	]]
)

--- Return entry points defined in the _nearest_ `setup.py` or `pyproject.toml`.
---
--- The files of interest are searched starting at `search_dir` followed by any parent directories,
--- stopping only when a match has been found or at the root of the filesystem.
---@param search_dir string? Where to search for project files (setup.py, pyproject.toml).
--- Defaults to current working directory.
---@return EntryPointDef[]? entrypoints, string? errmsg If a failure occurs at any stage,
--- `entrypoints` will be `nil` and `errmsg` will detail the reason for failure. Otherwise
--- `entrypoints` will be populated with the discovered entry points.
function M.aentry_points_from_project(search_dir)
	search_dir = search_dir or vim.fn.getcwd()

	local project_file, find_err = async.findfile(search_dir, "setup.py")
	if not project_file then
		return nil, find_err or "Could not find `setup.py` or `pyproject.toml`"
	end

	local file_content, errmsg = async.read_file(project_file)
	if not file_content then
		return nil, "Could not read `" .. project_file .. "`. Reason: " .. errmsg
	end

	local parser = vim.treesitter.get_string_parser(file_content, "python")
	local root = parser:parse()[1]:root()

	---@type EntryPointDef[]
	local result = {}

	for _, match in SETUP_PY_EP_QUERY:iter_matches(root, file_content) do
		local group = nil
		local entry = nil
		for id, nodes in pairs(match) do
			local capture_name = SETUP_PY_EP_QUERY.captures[id]
			if capture_name == "entrypoint.group" then
				group = tsutils.bounding_text(nodes, file_content)
			elseif capture_name == "entrypoint.entry" then
				entry = tsutils.bounding_text(nodes, file_content)
			end
		end

		if group ~= nil and entry ~= nil then
			---@type string[]
			local components = vim.tbl_map(vim.trim, vim.split(entry, "=", { plain = true }))

			table.insert(result, {
				group = group,
				name = components[1],
				value = vim.tbl_map(vim.trim, vim.split(components[2], ":", { plain = true })),
			})
		end
	end

	return result, nil
end

--- Returns entry-points available in the environment.
---@async
---@param group string? If non-nil, only selects entry-points in this group.
---@param python_path string? Path to python binary. Defaults to binary on PATH.
---@return EntryPointDef[]
function M.aentry_points(group, python_path)
	python_path = python_path or pyutils.default_path()

	local result = pyscripts.alist_entry_points_importlib(python_path, { group })
	return assert(result, "Could not find entry_points")
end

local ROOT_ATTR_QUERY_STRING = [[
	(module
		[
			(function_definition
				name: (_) @entry_point_name)
		  (expression_statement
				(assignment
					left: (_) @entry_point_name))
			(decorated_definition
				definition: (function_definition
					name: (_) @entry_point_name))
		]
		(#eq? @entry_point_name "%s")
	)
]]

--- Uses treesitter to find entry-point location in source code.
---
--- For simple *entry-points*, it should be more accurate.
---@async
---@param module_path string
---@param attr string
---@return integer? lineno, string? errmsg
local function aentry_point_location_ts(module_path, attr)
	if attr:find(".", nil, true) then
		return nil, "TS implementation can only be used with module attributes, use importlib instead."
	end

	local file_content, read_err = async.read_file(module_path)
	if not file_content then
		return nil, read_err
	end

	local ts_query = string.format(ROOT_ATTR_QUERY_STRING, attr)
	local parsed_ts_query = vim.treesitter.query.parse("python", ts_query)

	local parser = vim.treesitter.get_string_parser(file_content, "python")
	local root = parser:parse()[1]:root()

	local last_match = -1
	for _, node in parsed_ts_query:iter_captures(root, file_content) do
		local row = node:range()
		last_match = math.max(last_match, row + 1)
	end

	if last_match == -1 then
		return nil, "Could not find attr!"
	end
	return last_match, nil
end

---@class EntryPoint
---@field name string
---@field group string
---@field filename string
---@field lineno integer

--- Find entry-point definition in source.
---
--- Tries to use tree-sitter implementation first, then falls back to importlib
--- upon failure.
---
--- There are a few reasons for this:
---
--- 1. importlib can fail despite the entry-point being valid. If, for
---    example, a dependency is not available, importlib will fail without
---    returning the location of the entry-point.
---
--- 2. importlib will not return the exact location of an entry-point if it is
---    not a function. Take for example `ep = main`, where `main` is a function.
---    With the current importlib implementation, if `ep` is defined as the
---    entry-point, the location will resolve to the definition of `main`.
---
--- None of these issues appear when fetching the entry-point using
--- tree-sitter, as no dependency resolution occurs. However, it cannot follow
--- chains of attributes, such as `a.b.c`.
---@async
---@param def EntryPointDef
---@param python_path string? Path to python binary. Defaults to binary on PATH.
---@return EntryPoint? ep, string? errmsg
function M.aentry_point_location(def, python_path)
	python_path = python_path or pyutils.default_path()

	local file_path = pyscripts.afind_entry_point_origin_importlib(python_path, { def.value[1] })
	if file_path then
		---@type EntryPoint
		local result = {
			name = def.name,
			group = def.group,
			filename = file_path,
			lineno = 0,
		}

		-- Entry-point has no attr, point to top of module.
		if #def.value < 2 then
			return result, nil
		end

		local loc_ok, lineno = pcall(aentry_point_location_ts, file_path, def.value[2])
		if loc_ok and lineno ~= nil then
			result.lineno = lineno
			return result, nil
		end
	end

	local ep = pyscripts.afind_entry_point_importlib(python_path, { def.name, def.group })
	return ep, "could not find entry-point"
end

return M
