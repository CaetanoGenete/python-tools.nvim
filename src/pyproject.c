#include "lauxlib.h"
#include "lua.h"

#ifdef _WIN32
  // MSVC complains about tomlc17, disable warnings.
	#pragma warning(push, 0)
#endif

#include "tomlc17.h"

#ifdef _WIN32
	#pragma warning(pop)
#endif

#include <stdio.h>
#include <string.h>

#ifdef _WIN32
	#define LIB_EXPORT __declspec(dllexport)
#else
	#define LIB_EXPORT
#endif

/**
 * @brief Pushes entry-points found in `table` to the Lua `list` at the top of
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
 * @param list_size The size of the list at the top of Lua's stacks.
 * @param group The group name of the entry-points.
 * @param table The table wherein to look for entry-points.
 * @return The new size of the list.
 */
int _append_eps(lua_State *L, int list_size, const char *group, toml_datum_t table)
{
	for (int32_t i = 0; i < table.u.tab.size; ++i) {
		toml_datum_t value = table.u.tab.value[i];
		if (value.type != TOML_STRING)
			continue;

		lua_newtable(L);

		lua_pushstring(L, table.u.tab.key[i]);
		lua_setfield(L, -2, "name");

		lua_pushstring(L, group);
		lua_setfield(L, -2, "group");

		// Create value list - start

		int values_size = 0;
		lua_newtable(L);

		const char *value_str = value.u.str.ptr;
		const char *seg_start = value_str;

		while (1) {
			const char chr = *value_str;
			if (chr == ':' || chr == 0) {
				lua_pushlstring(L, seg_start, value_str - seg_start);
				lua_rawseti(L, -2, ++values_size);

				if (chr == 0)
					break;

				seg_start = value_str + 1;
			}
			++value_str;
		};

		lua_setfield(L, -2, "value");

		// Create value list - end.

		lua_rawseti(L, -2, ++list_size);
	}

	return list_size;
}

int l_entry_points(lua_State *L)
{
	int nreturn = 0;

	size_t src_len;
	const char *src = luaL_checklstring(L, 1, &src_len);
	const char *group_filter = luaL_optstring(L, 2, NULL);

	toml_result_t toml = toml_parse(src, (int)src_len);
	if (!toml.ok) {
		lua_pushnil(L);
		lua_pushstring(L, toml.errmsg);
		nreturn = 2;

		goto cleanup;
	}

	lua_newtable(L);
	++nreturn;

	toml_datum_t console_scripts = toml_seek(toml.toptab, "project.scripts");
	if (console_scripts.type != TOML_TABLE)
		goto cleanup;

	// The current size of the resultant list.
	int result_size = 0;

	if (!group_filter || strcmp("console_scripts", group_filter) == 0)
		result_size = _append_eps(L, 0, "console_scripts", console_scripts);

	toml_datum_t entry_points = toml_seek(toml.toptab, "project.entry-points");
	if (entry_points.type != TOML_TABLE)
		goto cleanup;

	for (int i = 0; i < entry_points.u.tab.size; ++i) {
		toml_datum_t value = entry_points.u.tab.value[i];
		if (value.type != TOML_TABLE)
			continue;

		const char *group = entry_points.u.tab.key[i];
		if (group_filter && strcmp(group, group_filter) != 0)
			continue;

		result_size = _append_eps(L, result_size, group, value);
	}

cleanup:
	toml_free(toml);
	return nreturn;
}

const static luaL_Reg lib[] = {
  {"entry_points", l_entry_points},
  {NULL, NULL},
};

LIB_EXPORT int luaopen_python_tools_meta__pyproject(lua_State *L)
{
	luaL_register(L, "_pyproject", lib);
	return 1;
}
