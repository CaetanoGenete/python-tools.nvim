## Installation

### Lazy.nvim

```lua
return {
	"CaetanoGenete/python-tools.nvim",
	lazy = true,
}
```

## Features

### Entry-point picker

Opens a telescope picker, with option to choose from entry-points available in
the current environment. See `python_tools.pickers.EntryPointPickerOptions` for
more details on what each option does.

```lua
-- Options are all defaults, no need to specify them, unless you really want to.
require("python_tools.pickers").find_entry_points({
	-- Filter selection to entry-points under this `group`. If unset, looks for
	-- ALL entry-points. See https://packaging.python.org/en/latest/specifications/entry-points/#data-model
	-- for more details on what an entry-point group is.
	group = nil,
	-- If `true`, searches the current active python environment, otherwise, parses the project file.
	use_importlib = true,
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
