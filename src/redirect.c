#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"

#include <memory.h>
#include <stdio.h>

#ifdef _WIN32
	#include <io.h>
	#define LIB_EXPORT __declspec(dllexport)
#else
	#include <unistd.h>
	#define LIB_EXPORT
#endif

typedef struct {
	int orig_src_fd;
	int dup_src_fd;
} redirect_state;

static int l_redirect(lua_State *L)
{
	FILE *src = *(FILE **)luaL_checkudata(L, 1, LUA_FILEHANDLE);
	if (src == NULL)
		return luaL_error(L, "redirect src is closed!");

	FILE *dst = *(FILE **)luaL_checkudata(L, 2, LUA_FILEHANDLE);
	if (dst == NULL)
		return luaL_error(L, "redirect dst is closed!");

	int src_fd = fileno(src);
	int dup_src_fd = dup(src_fd);

	fflush(dst);
	dup2(fileno(dst), src_fd);

	redirect_state data = {
	  .orig_src_fd = src_fd,
	  .dup_src_fd = dup_src_fd,
	};

	void *userdata = lua_newuserdata(L, sizeof(data));
	memcpy(userdata, &data, sizeof(data));

	return 1;
}

static int l_recover(lua_State *L)
{
	redirect_state state = *(redirect_state *)lua_touserdata(L, 1);

	dup2(state.dup_src_fd, state.orig_src_fd);
	close(state.dup_src_fd);

	return 0;
}

const static luaL_Reg lib[] = {
  {"redirect", l_redirect},
  {"recover", l_recover},
  {NULL, NULL},
};

LIB_EXPORT int luaopen_test_utils__redirect(lua_State *L)
{
	luaL_register(L, "_redirect", lib);
	return 1;
}
