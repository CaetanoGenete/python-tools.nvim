local M = {}

local wrap = require("python_tools._async._utils").wrap

---@async
---@nodiscard
---@type fun(path:string, flags:string|integer, mode:integer):string?,integer?
---@diagnostic disable-next-line: undefined-field
M.fs_open = wrap(vim.uv.fs_open, 3)

---@async
---@type fun(fd:integer):string?,integer?
---@diagnostic disable-next-line: undefined-field
M.fs_close = wrap(vim.uv.fs_close, 3)

---@async
---@nodiscard
---@type fun(fd:integer, size:integer, offset:integer?):string?,string?
---@diagnostic disable-next-line: undefined-field
M.fs_read = wrap(vim.uv.fs_read, 3)

---@class UVStat
---@field dev integer
---@field mode integer
---@field nlink integer
---@field uid integer
---@field gid integer
---@field rdev integer
---@field ino integer
---@field size integer
---@field blksize integer
---@field blocks integer
---@field flags integer
---@field gen integer
---@field type string

---@async
---@nodiscard
---@type fun(fd: integer): err:string?, stat:UVStat?
---@diagnostic disable-next-line: undefined-field
M.fs_fstat = wrap(vim.uv.fs_fstat, 1)

---@async
---@nodiscard
---@type fun(path: string): err:string?, stat:UVStat?
---@diagnostic disable-next-line: undefined-field
M.fs_stat = wrap(vim.uv.fs_stat, 1)

---@async
---@type fun(timer, interval: integer, repeat: integer)
---@diagnostic disable-next-line: undefined-field
M.timer_start = wrap(vim.uv.timer_start, 3)

---@class LuvDir

---@async
---@nodiscard
---@type fun(path: string, entries: integer?): err:string?, dir:LuvDir?
---@diagnostic disable-next-line: undefined-field
M.fs_opendir = wrap(function(dir, entries, callback)
	---@diagnostic disable-next-line: undefined-field
	return vim.uv.fs_opendir(dir, callback, entries)
end, 2)

---@class UVReadDirEntry
---@field name string
---@field type string

---@async
---@nodiscard
---@type fun(dir: LuvDir): err:string?, entries:UVReadDirEntry[]?
---@diagnostic disable-next-line: undefined-field
M.fs_readdir = wrap(vim.uv.fs_readdir, 1)

---@async
---@nodiscard
---@type fun(dir: LuvDir): err:string?, success:boolean?
---@diagnostic disable-next-line: undefined-field
M.fs_closedir = wrap(vim.uv.fs_closedir, 1)

return M
