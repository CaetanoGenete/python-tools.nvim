# python-tools.nvim

A set of utilities for developing Neovim tooling for python.

## Installation

### Lazy.nvim

```lua
return {
	"CaetanoGenete/python-tools.nvim",
	lazy = true,
	config = true,
}
```

### Compiling the c library

> [!NOTE]
>
> The library remains functional even if the c library is not available.
> However, entry-points will not be acquirable from _pyproject.toml_ files.

_python-tools_ provides a C99 library for reading entry-points from
_pyproject.toml_ files. If lazy does not build this for you (or fails). You may
need to compile it from source. If `cmake` is available, it should be as simple
as setting the _build_ field of the Lazy spec to the following:

```lua
return {
	"CaetanoGenete/python-tools.nvim",
	build = "cmake -S . -B build && cmake --install --prefix .",
	...,
}
```

> [!NOTE]
>
> The library remains functional even if the c library is not available.
> However, entry-points will not be acquirable from _pyproject.toml_ files.

Otherwise, the library consists of two source files, both found in the `./src/`
directory, [pyproject.c](./src/pyproject.c) and [tomlc17.c](./src/tomlc17.c).
These should both be compiled into the shared library `pyproject.so` (or
`pyproject.dll` on Windows), and installed to the directory
`{LUA_CPATH}/python_tools/meta/`.

The directory `./lib/` is added to `{CPATH}` on setup, so this would also be a
good directory wherein to install the library.

## Dependencies

- [NeoVim](https://github.com/neovim/neovim) 0.11
- Python >=3.8 (Your milage may vary for earlier versions)
- A python tree-sitter parser. (Can be installed using
  [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), for
  example).
- [Telescope](https://github.com/nvim-telescope/telescope.nvim) (Optional)

## Features

### Entry-point picker

![entrypoints_demo](./docs/assets/pick_entrypoints_demo.gif)

Opens a telescope picker, with option to choose from entry-points available in
the current environment. For more details on what each option does, see
`python_tools.pickers.EntryPointPickerOptions`.

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
	-- Python binary used when executing python scripts.
	--
	-- *Note*: if `use_importlib=true`, this should be the environment whose entrypoints are of
	-- interest.
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

### List entry points relative to the current buffer

By default, when `use_importlib=false`, the _current working directory_ is used
to scan for entrypoints. However, in large mono repos, to prevent having to
constanly switch directory, it may be convenient to list entry points relative
to the _current buffer_. This can be done via the `search_dir` option.

```lua
require("python_tools.pickers").find_entry_points({
	use_importlib = false,
	search_dir = vim.fn.expand("%:p:h"),
})
```

### Debugging entry points (using [nvim-dap](https://github.com/mfussenegger/nvim-dap))

The `python_tools.meta.entry_points` module can be used to easily execute an
entry-point in a debug context. Since _nvim-dap_ supports supplying threads as
arguments, `aentry_points_ts` can be used to select all the entry points defined
by the project.

> [!NOTE]
>
> Here it is preferable to use `aentry_points` to limit the returned entry
> points to those defined by the project. `aentry_points_importlib` will also
> list console scripts provided by _setuptools_, _black_, and other libraries.

```lua
---@param dap_coro thread
local function dap_abort(dap_coro)
	coroutine.resume(dap_coro, require("dap").ABORT)
end

---@async
---@param dap_coro thread
local function adebug_entrypoint(dap_coro)
	local eps, err =
		require("python_tools.meta.entry_points").aentry_points({ group = "console_scripts" })

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
# launcher.py

from importlib.metadata import entry_points
from sys import argv

eps = entry_points(name=argv[1], group=argv[2])
next(iter(eps)).load()()
```

## Development

### Dev dependencies

- [cmake](https://cmake.org/)
- [luarocks](https://luarocks.org/)
- [stylua](https://github.com/JohnnyMorganz/StyLua)
- [uv](https://astral.sh/uv/)
- [lua-language-server](https://luals.github.io/)
- [busted](https://lunarmodules.github.io/busted/)
- [tree-sitter-cli](https://tree-sitter.github.io/tree-sitter/) (If on windows)

To get started, simply run `make develop` and the environment should be setup
accordingly.

### Dockerfile

There is a simple dockerfile defined at the root of this project that creates an
image with all necessary dependencies. You may use it as a dev-container, or
otherwise as a test environmet by simply running:

```bash
docker build -t pytools .
docker run -it pytools
```

To ensure everything is ok, it's a good idea to try running the tests when first
building the image. The [next section](#executing-tests) covers this.

### Executing tests

You may execute tests using the busted provided script:

```bash
busted
```

Using luarocks (Which calls busted for you):

```bash
luarocks test
```

Or through make (Which also calls busted for you, but handles other
dependencies):

```bash
make test-dev # Or make test-all
```
