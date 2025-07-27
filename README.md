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
	group = nil,
	group_max_width = 12,
	debounce_duration_ms = 50,
	select_timeout_ms = 2000,
})
```
