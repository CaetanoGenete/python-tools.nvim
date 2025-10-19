A set of utilities for developing python NeoVim tooling.

## Installation

### Lazy.nvim

```lua
return {
	"CaetanoGenete/python-tools.nvim",
	lazy = true,
}
```

## Requirements

- [Telescope](https://github.com/nvim-telescope/telescope.nvim)
- [NeoVim](https://github.com/neovim/neovim) 0.11

## Features

### Entry-point picker

![entrypoints_demo](./docs/assets/pick_entrypoints_demo.gif)

Opens a telescope picker, with option to choose from entry-points available in
the current environment. See `python_tools.pickers.EntryPointPickerOptions` for
more details on what each option does.

```lua
-- Options are all defaults, no need to specify them, unless you really want to.
require("python_tools.pickers").find_entry_points({
	-- Whether to use python's [importlib](https://docs.python.org/3/library/importlib.html) module
	-- when determine entrypoints.
	--
	-- `use_importlib=true` provides a more accurate implementation, while the
	-- converse is more *flexible* and independant of the python environment.
	use_importlib = true,
	-- Filter selection to entry-points under this `group`. If unset, looks for
	-- ALL entry-points. See <https://packaging.python.org/en/latest/specifications/entry-points/#data-model>
	-- for more details on what an entry-point group is.
	group = nil,
	-- Only applicable if `use_importlib=false`.
	--
	-- All parent directories of this value will be searched to discover either
	-- a `pyproject.toml` or `setup.py` file, from which the entry-points will be read.
	--
	-- Defaults to the current working directory.
	search_dir = nil,
	-- Only applicable if `use_importlib=true`.
	--
	-- Path to the python environment binary, wherein to look for entry-points.
	--
	-- The path is resolved to be the first non-nil value from:
	--  - python_path
	--  - vim.g.pytools_default_python_path
	--  - "python"
	python_path = nil,
	-- Maximum display width, in the *results* window, for the entry-point
	-- group.
	group_max_width = 12,
	-- The duration in milliseconds for which an entry should be selected,
	-- before the entry-point location is fetched.
	debounce_duration_ms = 50,
	-- How long to wait, in milliseconds, for an entry-point to be found once
	-- selected, before throwing an error.
	select_timeout_ms = 2000,
})
```

## Recipes

### Debugging entry points (using nvim-dap)

The `python_tools.meta.entry_points` module can be used to easily execute an
entry-point in a debug context. Since _nvim-dap_ supports supplying threads as
arguments, `aentry_points_ts` can be used to select all the entry points defined
by the project.

> [!NOTE]
>
> Here it is preferable to use `aentry_points_ts` to limit the returned entry
> points to those defined by the project. `aentry_points_importlib` will also
> list console scripts provided by _setuptools_ and _black_, for example.

```lua
---@param dap_coro thread
local function dap_abort(dap_coro)
	coroutine.resume(dap_coro, require("dap").ABORT)
end

---@async
---@param dap_coro thread
local function adebug_entrypoint(dap_coro)
	local eps, err =
		require("python_tools.meta.entry_points").aentry_points_ts({ group = "console_scripts" })

	if eps == nil then
		vim.notify(("Failed to find entry_points: %s"):format(err), vim.log.levels.ERROR)
		dap_abort(dap_coro)
		return
	end

	---@param ep EntryPointDef
	local function on_selected(ep)
		if ep == nil then
			dap_abort(dap_coro)
			return
		end
		coroutine.resume(dap_coro, { ep.name, ep.group })
	end

	vim.ui.select(eps, {
		prompt = "Choose an entry point:",
		format_item = function(ep)
			return ("(%s) %s"):format(ep.group, ep.name)
		end,
	}, on_selected)
end

return {
	type = "python",
	request = "launch",
	name = "Launch console_script",
	-- launcher.py is a helper script defined lower in the README. Replace with
	-- an absolute path to ensure it can always be found.
	program = "launcher.py",
	args = function()
		return coroutine.create(adebug_entrypoint)
	end,
}
```

Since _console_scripts_ aren't python files per say, a small script, as below,
acts as an adapter to allow debugpy to execute the entry point. **NOTE**, this
script only works for python version _3.10+_.

```python
from importlib.metadata import entry_points
from sys import argv

eps = entry_points(name=argv[1], group=argv[2])
next(iter(eps)).load()()
```
