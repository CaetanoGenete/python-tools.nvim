---@meta

---@class luassert.internal
local internal = {}

--- Polls for until `fn` returns true. If `opts.timeout` is reached before `fn` returns true, the
--- assertion fails.
---
---@param fn fun():boolean The polling function.
---@param opts? AssertPollOpts Additional options.
function internal.poll(fn, opts) end

--- Same as `assert.same`, but only compares on the keys available in `lhs`.
---
---@param lhs table<string, any>
---@param rhs table<string, any>
function internal.subset(lhs, rhs) end

--- Compares paths after normalisation.
---
---@param expected string
---@param actual string
function internal.paths_same(expected, actual) end
