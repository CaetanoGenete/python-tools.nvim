local say = require("say")
local assert = require("luassert")
local util = require("luassert.util")

DEFAULT_ASSERT_POLL = 1000

---@class AssertPollOpts
---@field timeout integer?
---@field interval integer?

local function poll(_, arguments)
	if #arguments == 0 then
		error("`assert.poll` takes at least one argument!")
	end

	local poll_fn = arguments[1]
	if type(poll_fn) ~= "function" then
		error("First argument to `assert.poll` should be a function!")
	end

	---@type AssertPollOpts
	local opts = arguments[2] or {}

	if type(opts) ~= "table" then
		error("Second argument to `assert.poll` should be a table!")
	end

	local time = opts.timeout or DEFAULT_ASSERT_POLL
	vim.wait(time, poll_fn, opts.interval)

	return poll_fn()
end

say:set("assertion.poll.positive", "Expected poll to succeed!")
say:set("assertion.poll.negative", "Expected poll to fail!")
assert:register("assertion", "poll", poll, "assertion.poll.positive", "assertion.poll.negative")

local function subset(_, arguments)
	if #arguments < 2 then
		error("`assert.poll` takes at least two arguments!")
	end

	local lhs = arguments[1]
	local rhs = arguments[2]

	if type(lhs) ~= "table" then
		error("First argument to `assert.subset` should be a table!")
	end

	if type(rhs) ~= "table" then
		error("Second argument to `assert.subset` should be a table!")
	end

	local sub = require("test.utils").tbl_subset(rhs, vim.tbl_keys(lhs))
	-- for key in pairs(lhs) do
	-- 	sub[key] = rhs[key]
	-- end
	--
	local result, crumbs = util.deepcompare(lhs, sub, true)

	arguments.fmtargs = arguments.fmtargs or {}
	arguments.fmtargs[1] = { crumbs = crumbs }
	arguments.fmtargs[2] = { crumbs = crumbs }

	return result
end

say:set("assertion.subset.positive", "Expected:\n%s\nto be a subset of:\n%s")
say:set("assertion.subset.negative", "Expected:\n%s\nto NOT be a subset of:\n%s")
assert:register(
	"assertion",
	"subset",
	subset,
	"assertion.subset.positive",
	"assertion.subset.negative"
)

local function paths_same(_, arguments)
	if #arguments ~= 2 then
		error("`assert.paths_same` takes exactly two arguments!")
	end

	local expected = arguments[1]
	local actual = arguments[2]

	if type(expected) ~= "string" then
		error("First argument to `assert.paths_same` should be a string!")
	end

	if type(actual) ~= "string" then
		error("First argument to `assert.paths_same` should be a string!")
	end

	arguments[3] = vim.fs.normalize(vim.fs.abspath(expected))
	arguments[4] = vim.fs.normalize(vim.fs.abspath(actual))
	return arguments[3] == arguments[4]
end

say:set(
	"assertion.paths_same.positive",
	[[Paths are not the same!
Expected:%s
Actual  :%s
Expected normalised: %s
Actual normalised  : %s]]
)
say:set("assertion.paths_same.negative", "Expectect paths to be different, but were the same.")
assert:register(
	"assertion",
	"paths_same",
	paths_same,
	"assertion.paths_same.positive",
	"assertion.paths_same.negative"
)
