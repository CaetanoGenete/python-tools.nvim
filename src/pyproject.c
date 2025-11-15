#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
#include "tomlc17.h"

#include <stdio.h>

#ifdef _WIN32
	#define LIB_EXPORT __declspec(dllexport)
#else
	#define LIB_EXPORT
#endif

/**
 * @brief Pushes entry-points found in `table` to Lua `table` at the top of
 * Lua's stack.
 *
 * Example entry:
 * ```lua
 * {
 *   name = "<string>",
 *   group = "<string>",
 *   value = "<string[]>",
 * }
 * ```
 *
 * @param L The lua state.
 * @param group The group name of the entry-points.
 * @param table The table wherein to look for entry-points.
 * @param list_size The size of the list at the top of Lua's stacks.
 * @return The new size of the list.
 */
int _append_eps(lua_State *L, int list_size, const char *group, toml_datum_t table)
{
	for (int32_t i = 0; i < table.u.tab.size; ++i) {
		toml_datum_t value = table.u.tab.value[i];
		if (value.type != TOML_STRING)
			continue;

		lua_pushinteger(L, ++list_size);
		lua_newtable(L);

		lua_pushstring(L, table.u.tab.key[i]);
		lua_setfield(L, -2, "name");

		lua_pushstring(L, group);
		lua_setfield(L, -2, "group");

		// Create values list - start

		int values_size = 0;
		lua_newtable(L);

		const char *value_str = value.u.str.ptr;
		const char *seg_start = value_str;

		for (;;) {
			const char chr = *value_str;
			if (chr == ':' || chr == 0) {
				lua_pushinteger(L, ++values_size);
				lua_pushlstring(L, seg_start, value_str - seg_start);
				lua_settable(L, -3);

				if (chr == 0)
					break;

				seg_start = value_str + 1;
			}
			++value_str;
		};

		lua_setfield(L, -2, "value");

		// Create values list - end.

		lua_settable(L, -3);
	}

	return list_size;
}

int l_entry_points(lua_State *L)
{
	int nreturn = 0;

	FILE *src = *(FILE **)luaL_checkudata(L, 1, LUA_FILEHANDLE);

	toml_result_t toml = toml_parse_file(src);
	if (!toml.ok) {
		luaL_error(L, "Failed to parse toml file: %s!", toml.errmsg);
		goto cleanup;
	}

	lua_newtable(L);
	++nreturn;

	toml_datum_t console_scripts = toml_seek(toml.toptab, "project.scripts");
	if (console_scripts.type != TOML_TABLE) {
		goto cleanup;
	}

	int list_size = _append_eps(L, 0, "console_scripts", console_scripts);

	toml_datum_t entry_points = toml_seek(toml.toptab, "project.entry-points");
	if (entry_points.type != TOML_TABLE) {
		goto cleanup;
	}

	for (int i = 0; i < entry_points.u.tab.size; ++i) {
		toml_datum_t value = entry_points.u.tab.value[i];
		if (value.type != TOML_TABLE)
			continue;

		const char *group = entry_points.u.tab.key[i];
		list_size = _append_eps(L, list_size, group, value);
	}

cleanup:
	toml_free(toml);
	return nreturn;
}

const static luaL_Reg lib[] = {
  {"entry_points_from_pyproject", l_entry_points},
  {NULL, NULL},
};

LIB_EXPORT int luaopen_python_tools_meta_pyproject(lua_State *L)
{
	luaL_register(L, "pyproject", lib);
	return 1;
}
