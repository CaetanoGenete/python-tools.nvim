local M = {}

---@nodiscard
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

local function root_dir()
	return vim.fs.normalize(vim.fs.abspath(debug.getinfo(1).source:match("@?(.*/)") .. "../../"))
end

---@class BuildMessage
---@field msg string
---@field level number

---@param msg BuildMessage
local function echo_message_handler(msg)
	vim.notify("python_tools:" .. msg.msg, msg.level)
end

local MIN_CLIB_VERSION = "0.1.0"

---@return boolean
local function verify_clib()
	local ok, pyproject = pcall(require, "python_tools.meta._pyproject")
	if not ok then
		return false
	end

	local version_ok, clib_version = pcall(pyproject.version)
	if not version_ok then
		return false
	end

	if vim.version.cmp(clib_version, MIN_CLIB_VERSION) < 0 then
		return false
	end

	return true
end

---Attempts to build the c library for python_tools from source.
---
---@param force boolean?
---@param message_callback fun(msg: BuildMessage)?
function M.install_library(force, message_callback)
	message_callback = message_callback or echo_message_handler

	if force == nil or force == false then
		if verify_clib() then
			message_callback({
				msg = "c library already installed and at correct version, nothing to do...",
				level = vim.log.levels.INFO,
			})
			return
		end
	end

	message_callback({
		msg = "c library missing or out of date, installing...",
		level = vim.log.levels.INFO,
	})

	local cwd = root_dir()

	local cmake = executable("cmake", { ".exe" })
	if cmake then
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
			local result = vim.system(cmd, { cwd = cwd }):wait()
			if result.code ~= 0 then
				ok = false

				message_callback({
					msg = ("cmake step %d failed with exit code: %d"):format(step, result.code),
					level = vim.log.levels.INFO,
				})

				break
			end
		end

		if ok then
			message_callback({
				msg = "cmake install succeeded!",
				level = vim.log.levels.INFO,
			})
			return
		end
	end

	local luarocks = executable("luarocks", { ".exe", ".bat" })
	if luarocks then
		message_callback({
			msg = "luarocks found! Trying to build using `luarocks make`.",
			level = vim.log.levels.INFO,
		})

		local result = vim
			.system({
				luarocks,
				"make",
				"--no-install",
			}, { cwd = cwd })
			:wait()

		if result.code == 0 then
			local libpath = vim.fs.joinpath(cwd, "python_tools")
			-- Note: `luarocks make` install clib relative to the current directory (There is no way to
			-- change this at the moment...), move the binaries to the lib/.
			local ok = os.rename(libpath, vim.fs.joinpath(cwd, "lib/python_tools"))
			if ok then
				message_callback({
					msg = "Luarocks install succeeded!",
					level = vim.log.levels.INFO,
				})
				return
			end

			message_callback({
				msg = "luarocks make succeeded, but failed to install. cleaning up...",
				level = vim.log.levels.INFO,
			})

			vim.fs.rm(libpath, { recursive = true, force = true })
		else
			message_callback({
				msg = ("`luarocks make` failed with exit code: %d"):format(result.code),
				level = vim.log.levels.INFO,
			})
		end
	end

	message_callback({
		msg = "Failed to install python_tools clib! You may not be able to use certain features",
		level = vim.log.levels.ERROR,
	})

	-- TODO: Add download step if all else fails.
end

---@class PythonToolsOptions
---@field verify_clibrary boolean?

---@param opts PythonToolsOptions?
function M.setup(opts)
	opts = opts or {}

	local root = root_dir()
	-- Setup package path to be able to find c libraries
	package.cpath = package.cpath
		.. ";"
		.. vim.fs.joinpath(root, INSTALL_PATH, "?.dll")
		.. ";"
		.. vim.fs.joinpath(root, INSTALL_PATH, "?.so")
		.. ";"

	if opts.verify_clibrary == false then
		return
	end

	if not verify_clib() then
		vim.notify(
			"python_tools: C library is not installed, some features may not work!",
			vim.log.levels.WARN
		)
	end
end

return M
