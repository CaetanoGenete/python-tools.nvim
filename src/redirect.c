#include "lauxlib.h"
#include "lua.h"
#include <stdio.h>

#ifdef _WIN32
#define TTY "CON"
#define LIB_EXPORT __declspec(dllexport)
#else
#define TTY "/dev/tty"
#define LIB_EXPORT
#endif

static int l_redirect(lua_State *L) {
  const char *file = lua_tostring(L, 1);
  FILE *ptr;
  freopen_s(&ptr, file, "a", stdout);
  freopen_s(&ptr, file, "a", stderr);
  return 0;
}

static int l_recover(lua_State *L) {
  FILE *ptr;
  freopen_s(&ptr, TTY, "a", stdout);
  freopen_s(&ptr, TTY, "a", stderr);
  return 0;
}

const static luaL_Reg lib[] = {
    {"redirect", l_redirect},
    {"recover", l_recover},
    {NULL, NULL},
};

LIB_EXPORT int luaopen_redirect(lua_State *L) {
  luaL_register(L, "redirect", lib);
  return 1;
}
