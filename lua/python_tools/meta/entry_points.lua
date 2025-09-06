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

--- Uses treesitter to try discover entrypoints defined by the project.
---
--- If `project_file` points to *setup.py*, it is impossible to guarantee that all (or any)
--- entrypoints will be returned. For accurate results, the entrypoint definitions must be passed
--- inline to the relevant argument of `setuptools.setup`, as shown in the following code snippet:
--- ```python
--- setup(
---    name="mock-setup_py-repo",
---    version="0.1.0",
---    entry_points={
---        "console_scripts": [
---            "ep1=hello:ep1",
---        ],
---    },
--- )
--- ```
--- This function will fail to detect the entrypoints otherwise, for example:
--- ```python
--- my_entry_points = {
---     "console_scripts": [
---         "ep1=hello:ep1",
---     ],
--- }
---
--- setup(
---    name="mock-setup_py-repo",
---    version="0.1.0",
---    entry_points=my_entry_points,
--- )
--- ```
--- For guaranteed results, checkout `python_tools.meta.entry_points.entry_points`.
---
---@param project_file string Path to *setup.py* or *pyproject.toml*.
---@param group string? Optional filter.
---@return EntryPointDef[]? entrypoints, string? errmsg If a failure occurs at any stage,
--- `entrypoints` will be `nil` and `errmsg` will detail the reason for failure. Otherwise
--- `entrypoints` will be populated with the discovered entry points.
function M.aentry_points_from_project(project_file, group)
	local file_content, errmsg = async.read_file(project_file)
	if not file_content then
		return nil, "Could not read `" .. project_file .. "`. Reason: " .. errmsg
	end

	local parser = vim.treesitter.get_string_parser(file_content, "python")
	local root = parser:parse()[1]:root()

	---@type EntryPointDef[]
	local result = {}

	for _, match in SETUP_PY_EP_QUERY:iter_matches(root, file_content) do
		local result_group = nil
		local result_entry = nil
		for id, nodes in pairs(match) do
			local capture_name = SETUP_PY_EP_QUERY.captures[id]

			if capture_name == "entrypoint.group" then
				result_group = tsutils.bounding_text(nodes, file_content)
			elseif capture_name == "entrypoint.entry" then
				result_entry = tsutils.bounding_text(nodes, file_content)
			end
		end

		if group ~= nil and result_group ~= group then
			result_group = nil
		end

		if result_group ~= nil and result_entry ~= nil then
			---@type string[]
			local components = vim.tbl_map(vim.trim, vim.split(result_entry, "=", { plain = true }))

			table.insert(result, {
				group = result_group,
				name = components[1],
				value = vim.tbl_map(vim.trim, vim.split(components[2], ":", { plain = true })),
			})
		end
	end

	return result, nil
end

---@async
---@param search_dir string
---@return string? project_file, string? errmsg
local function afind_project_file(search_dir)
	local project_file, find_err = async.findfile(search_dir, { "pyproject.toml", "setup.py" })
	return project_file, find_err
end

---@class EntryPointsOptions
--- If `true`, the python environment pointed to by `python_path` will be used to fetch the
--- entry-points. This will exactly return **ALL** possible entry-points available in the current
--- environment
---
--- If `false`, the contents of the project file (either `pyproject.toml` or `setup.py`), whose
--- discovery is controlled by `search_dir`, will be parsed to extract the entry-points.
---
--- Use of either depends on the desired outcome, whilst using *importlib* guarantees correctness;
--- syntax errors, package resolution errors, and other such issues in the project will cause the
--- search to fail. The non-*importlib* implementation is marketly more resilient to such issues, at
--- the cost of some assumptions, see `aentry_points_from_project` for more details.
---
--- Additionally, the *importlib* implementation depends on the existence of a python virtual
--- environment. Which is likely the case for single project repositories, but may not be so for
--- large mono-repos. In the latter case, the non-*importlib* implementation may be more convenient.
---
--- Another point of advantage for the non-*importlib* implementation is the greater refinement in
--- its response. *importlib* will provide entry-points not defined by the current project (if
--- available), which may not always be desirable. Whereas, the non-*importlib* option is guaranteed
--- to return only those defined by the current repository.
---
--- Defaults to `true`.
---@field use_importlib boolean?
--- Filter selection to entry-points under this `group`. If unset, looks for **ALL** entry-points.
---
--- See <https://packaging.python.org/en/latest/specifications/entry-points/#data-model> for more
--- details on what an entry-point *group* is.
---
--- Defaults to `nil`.
---@field group string?
---	Only applies if `use_importlib = True`.
---
--- Path to the python environment binary, wherein to look for entry-points.
---
--- The path is resolved to be the first non-nil value from:
---  - `python_path`
---  - `vim.g.pytools_default_python_path`
---  - `"python"`
---
--- Defaults to binary on PATH.
---@field python_path string?
--- Only applies if `use_importlib = False`.
---
--- When looking for entry-points, this and every parent directory will be scanned to find either
--- `pyproject.toml` or `setup.py`. If the search is successful, the entry-points will from therein
--- be extracted.
---
--- Defaults to the _current working directory_.
---@field search_dir string?

--- Returns the entry-points of the python project or environment, depending on whether
--- `options.use_importlib` is `false` or `true` respectively.
---
--- See [use_importlib](lua://EntryPointsOptions.use_importlib) for a deeper discussion.
---
---@async
---@param options EntryPointsOptions?
---@return EntryPointDef[]
function M.aentry_points(options)
	options = options or {}

	if options.use_importlib == nil or options.use_importlib then
		local python_path = options.python_path or pyutils.default_path()

		local result = pyscripts.alist_entry_points_importlib(python_path, { options.group })
		return assert(result, "Could not find entry_points")
	end

	local search_dir = options.search_dir or vim.fn.getcwd()

	local project_file, find_err = afind_project_file(search_dir)
	if not project_file then
		error(find_err or "Could not find `setup.py` or `pyproject.toml`")
	end

	local entry_points, ep_err = M.aentry_points_from_project(project_file, options.group)
	if entry_points == nil then
		error(ep_err)
	end
	return entry_points
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

---@class EntryPointLocationOptions
--- If `true`, the python environment pointed to by `python_path` will be used to locate the
--- entry-points.
---
--- If `false`, the entry-point location will be deduced from the `search_dir` and the module path.
---
--- Defaults to `true`.
---@field use_importlib boolean?
---	Only applies if `use_importlib = True`.
---
--- Path to the python environment binary, wherein the entry-point is available.
---
--- The path is resolved to be the first non-nil value from:
---  - `python_path`
---  - `vim.g.pytools_default_python_path`
---  - `"python"`
---
--- Defaults to binary on PATH.
---@field python_path string?
--- Only applies if `use_importlib = False`.
---
--- When looking for entry-points, this and every parent directory will be scanned to find either
--- `pyproject.toml` or `setup.py`. If the search is successful, the entry-point origin will be
--- determined relative to this directory.
---
--- Defaults to the _current working directory_.
---@field search_dir string?

---@class EntryPoint
---@field name string
---@field group string
---@field filename string
---@field lineno integer

local MODULE_SEARCH_DIRS = { "src", "" }

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
---@param def EntryPointDef The entry-point whose location to discover. Can be obtained, for
---example, by using `M.aentry_points`.
---@param options EntryPointLocationOptions?
---@return EntryPoint? ep, string? errmsg
function M.aentry_point_location(def, options)
	options = options or {}

	local python_path = options.python_path
	local use_importlib = options.use_importlib

	if use_importlib == nil then
		use_importlib = true
	end

	local module = def.value[1]

	local file_path = nil
	if use_importlib then
		python_path = python_path or pyutils.default_path()
		file_path = pyscripts.afind_entry_point_origin_importlib(python_path, { module })
	else
		local project_file = afind_project_file(options.search_dir or vim.fn.getcwd())
		if project_file then
			local project_dir = vim.fs.dirname(project_file)
			local module_path = vim.fs.normalize(module:gsub("\\.", "/") .. ".py")

			for _, candidate in ipairs(MODULE_SEARCH_DIRS) do
				local candidate_path = vim.fs.joinpath(project_dir, candidate, module_path)
				-- Note: checking if errmsg of `fs_stat` is none
				if async.fs_stat(candidate_path) == nil then
					file_path = candidate_path
					break
				end
			end
		end
	end

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

	if use_importlib then
		---@cast python_path string
		local ep, errcode = pyscripts.afind_entry_point_importlib(python_path, { def.name, def.group })
		if errcode == 0 then
			return ep, nil
		end
	end

	return nil, "could not find entry-point"
end

return M
