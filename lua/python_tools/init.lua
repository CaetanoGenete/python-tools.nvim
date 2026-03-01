local M = {}

local async = require("python_tools._async")

---@param cmd string
---@param exts string[]
---@return string?
local function executable(cmd, exts)
	if vim.fn.executable(cmd) then
		return cmd
	end

	if vim.fn.has("win32") then
		for _, ext in ipairs(exts) do
			local candidate = ("%s.%s"):format(cmd, ext)
			if vim.fn.executable(candidate) then
				return candidate
			end
		end
	end

	return nil
end

local BUILD_PATH = "build"
local INSTALL_PATH = "lib"

---@async
---@param cwd string
local function build_or_install(cwd)
	local cmake = executable("cmake", { ".exe" })
	if cmake then
		vim.notify("cmake found! Trying to build using cmake.", vim.log.levels.INFO)

		local cmds = {
			{
				cmake,
				"-S",
				".",
				"-B",
				BUILD_PATH,
				"-DCMAKE_BUILD_TYPE=release",
				"-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
				"-DBUILD_REDIRECTLIB=ON",
			},
			{
				cmake,
				"--build",
				BUILD_PATH,
				"--config",
				"release",
			},
			{
				cmake,
				"--install",
				BUILD_PATH,
				"--prefix",
				INSTALL_PATH,
			},
		}

		local ok = true
		for step, cmd in ipairs(cmds) do
			local result = async.system(cmd, { cwd = cwd })
			if result.code ~= 0 then
				ok = false

				vim.notify(
					("cmake step %d failed with exit code: %d"):format(step, result.code),
					vim.log.levels.INFO
				)
				break
			end
		end

		if ok then
			vim.notify("cmake install succeeded!")
			return
		end
	end

	local luarocks = executable("luarocks", { ".exe", ".bat" })
	if luarocks then
		vim.notify("luarocks found! Trying to build using `luarocks make`.", vim.log.levels.INFO)

		local result = async.system({
			luarocks,
			"make",
			"--no-install",
		}, { cwd = cwd })

		if result.code == 0 then
			local libpath = vim.fs.joinpath(cwd, "python_tools")
			-- Note: `luarocks make` install clib relative to the current directory (There is no way to
			-- change this at the moment...), move the binaries to the lib/.
			local ok = os.rename(libpath, vim.fs.joinpath(cwd, "lib/python_tools"))
			if ok then
				vim.notify("Luarocks install succeeded!")
				return
			end

			vim.notify(
				"luarocks make succeeded, but failed to install. cleaning up...",
				vim.log.levels.INFO
			)

			vim.fs.rm(libpath, { recursive = true, force = true })
		else
			vim.notify(
				("`luarocks make` failed with exit code: %d"):format(result.code),
				vim.log.levels.INFO
			)
		end
	end

	vim.notify(
		"Failed to install python_tools clib! You may not be able to use certain features",
		vim.log.levels.ERROR
	)

	-- TODO: Add download step if all else fails.
end

--- @class PythonToolsOptions
--- @field install_clib boolean? If true, try install the c library if it's not already available.
---		Defaults to `true`.

---@param opts PythonToolsOptions?
function M.setup(opts)
	opts = opts or {}

	local root =
		vim.fs.normalize(vim.fs.abspath(debug.getinfo(1).source:match("@?(.*/)") .. "../../"))

	-- Setup package path to be able to find c libraries
	package.cpath = package.cpath
		.. ";"
		.. vim.fs.joinpath(root, INSTALL_PATH, "?.dll")
		.. ";"
		.. vim.fs.joinpath(root, INSTALL_PATH, "?.so")
		.. ";"

	local ok = pcall(require, "python_tools.meta._pyproject")
	if ok then
		return
	end

	if opts.install_clib == nil or opts.install_clib then
		vim.notify("clib not installed, trying to install now.", vim.log.levels.INFO)
		async.run(build_or_install, root)
	end
end

return M
