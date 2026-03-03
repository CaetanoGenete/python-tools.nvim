# python-tools.nvim

A set of utilities for developing Neovim tooling for python.

## Installation

### Lazy.nvim

If using lazy, installation should be as simple as adding the following plugin
spec entry:

```lua
return {
	"CaetanoGenete/python-tools.nvim",
	lazy = true,
	config = true,
}
```

If issues occur during the build step, or there is no build step, see
[how to build the C library](#building-the-c-library).

### Other package managers

*python_tools* expects:

1. All Dependencies to be available (See [Dependencies](#dependencies)].
2. (Optional) The C library to be installed via
   `require("python_tools").install_library`, or manually (See
    [how to build the C library](#building-the-c-library)).
3. (Optional) `require("python_tools").setup()` to be called (recommended if
   the C library is installed).

It is recommended to run `require("python_tools").setup()` before using this
plugin. Setup, amongst other things, will verify the C library is correctly
installed and usable. Failure to install the C library will **not** leave the
plugin unusable, but may result in some features erring.

## Dependencies

- [NeoVim](https://github.com/neovim/neovim) 0.11+
- Python 3.8+ (Your milage may vary for earlier versions)
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
to scan for entrypoints. However, in large mono repos, to prevent excessively
switching working directory, it may be convenient to list entry points relative
to the _current buffer_. This can be done via the `search_dir` option.

```lua
require("python_tools.pickers").find_entry_points({
	use_importlib = false,
	search_dir = vim.fn.expand("%:p:h"),
})
```

### Debugging entry points (using [nvim-dap](https://github.com/mfussenegger/nvim-dap))

The `python_tools.meta.entry_points` module can be used to easily execute an
entry-point with a debugger attached. Since _nvim-dap_ supports supplying
threads as arguments, the `aentry_points` function can be used to select all
the entry points defined by the project.

> [!NOTE]
>
> Here it is preferable to use `aentry_points` to limit the returned results
> to those defined by the project. `aentry_points_importlib` will also list
> console_scripts provided by _setuptools_, _black_, and other libraries.

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

## Building the C library

> [!NOTE]
>
> The plugin remains functional even if the C library is not available. However,
> entry-points will not be acquirable from _pyproject.toml_ files, unless using
> importlib.

_python-tools_ provides a C99 library for reading entry-points from
_pyproject.toml_ files. If not using Lazy or, if Lazy does not build this for
you (or fails); it may be necessary to compile from source.

### Invoking the build function

Before all else, attempt invoking the build function defined at the
`python-tools` module:

```lua
require("python_tools").install_library(true)
```

This will automatically attempt all the steps below. If this fails, only then
consider further options.

### Using CMake

The project defines a [CMakeLists.txt](https://cmake.org/) file to assist
building. A typical cmake install pipeline is as follows (executed from the
plugin's root directory, where the top level `CMakeLists.txt` is found):

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=release
cmake --build build --config release
cmake --install build --prefix ./lib/
```

### Using Luarocks

> [!WARNING]
>
> This approach is not recommended, as it may later conflict with the typically
> installed binary.
>
> If necessary, try relying on Lazy's hererocks implementation. Unlike
> installing through luarocks directly, purging the plugin will likewise purge
> the C library binary.


If [luarocks](https://luarocks.org/) is installed, the c-library may be built
and installed by running the following at the project's root directory:

```bash
luarocks build
```

If using Lazy, by appropriately setting the _build_ field of the Lazy plugin
spec, Lazy _v11+_ can be instructed to use luarocks to compile the library.

> [!IMPORTANT]
>
> If on Windows, unless your environment is appropriately setup, you may need to
> use the _Developer Command Prompt_.

```lua
-- Lazy plugin spec:
return {
	"CaetanoGenete/python-tools.nvim",
	build = "rockspec",
	...,
}
```


### Manual compilation

> [!WARNING]
>
> These steps are more likely to become obsolete, as compared to the above
> methods.

The library consists of two source files, both found in the `./src/` directory,
[pyproject.c](./src/pyproject.c) and [tomlc17.c](./src/tomlc17.c). These should
both be compiled into the shared library `_pyproject.so` (or `_pyproject.dll` on
Windows), and installed to the directory `<cpath-dir>/python_tools/meta/`. Here,
`<cpath-dir>` is any valid directory on the Lua `CPATH`; see the
[Lua 5.1 docs](https://www.lua.org/manual/5.1/manual.html#pdf-package.cpath) for
more information.

The directory `./lib/` is added to `CPATH` on setup, so this would also be a
good directory wherein to install the library.

For example, if using `gcc` on a _unix_ OS:

```bash
mkdir -p ./lib/python_tools/meta/
gcc -shared -fPIC -O3 -I/usr/include/lua5.1/ -o ./lib/python_tools/meta/_pyproject.so ./src/pyproject.c ./src/tomlc17.c
```

### Precompiled binaries

This feature is planned, but not currently available...

## Development

See [developers.md](./docs/developers.md).
