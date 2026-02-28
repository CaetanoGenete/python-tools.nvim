local M = {}

local async = require("python_tools._async")

local ROOT = vim.fs.normalize(vim.fs.abspath(debug.getinfo(1).source:match("@?(.*/)") .. "../../"))

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

local BUILD_PATH = "build-ts"

local function build_or_install()
	-- Try build from source

	local cmake = executable("cmake", { ".exe" })
	if cmake then
		local result = async.system({
			cmake,
			"-S",
			".",
			"-B",
			BUILD_PATH,
			"-DCMAKE_BUILD_TYPE=release",
			"-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
			"-DBUILD_REDIRECTLIB=ON",
		}, { cwd = ROOT })

		if result.code == 0 then
			return
		end
	end

	local luarocks = executable("luarocks", { ".exe", ".bat" })
	if luarocks then
		local result = async.system({
			cmake,
			"-S",
			".",
			"-B",
			BUILD_PATH,
			"-DCMAKE_BUILD_TYPE=release",
			"-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
			"-DBUILD_REDIRECTLIB=ON",
		}, { cwd = ROOT })

		if result.code == 0 then
			return
		end
	end
end

function M.setup()
	-- Setup package path to be able to find c libraries
	package.cpath = package.cpath
		.. ";"
		.. vim.fs.joinpath(ROOT, "lib/?.dll")
		.. ";"
		.. vim.fs.joinpath(ROOT, "lib/?.so")
		.. ";"

	local ok = pcall(require, "python_tools.meta._pyproject")
	if ok then
		return
	end

	async.run(build_or_install)
end

return M
