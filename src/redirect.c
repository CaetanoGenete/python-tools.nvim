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

static const char *redirect_err = "Failed to redirect %s to '%s'!";

static int l_redirect(lua_State *L) {
  const char *file = lua_tostring(L, 1);

  FILE *stream = freopen(file, "a", stdout);
  if (!stream) {
    return luaL_error(L, redirect_err, "stdout", file);
  }

  if (!freopen(file, "a", stderr)) {
    fclose(stream);
    return luaL_error(L, redirect_err, "stderr", file);
  }

  return 0;
}

static const char *recover_err = "Failed to redirect %s back to console!";

static int l_recover(lua_State *L) {
  if (!freopen(TTY, "a", stdout)) {
    return luaL_error(L, recover_err, "stdout");
  }

  if (!freopen(TTY, "a", stderr)) {
    return luaL_error(L, recover_err, "stderr");
  }

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
