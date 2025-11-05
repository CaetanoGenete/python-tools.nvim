cmake_minimum_required(VERSION 3.14)

project(python_tools C)

# See: https://cmake.org/cmake/help/latest/module/FindLua.html
find_package(Lua 5.1 REQUIRED)
if(NOT TARGET Lua::Lua)
  add_library(Lua::Lua INTERFACE IMPORTED)
  set_target_properties(
    Lua::Lua
    PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${LUA_INCLUDE_DIR}"
      INTERFACE_LINK_LIBRARIES "${LUA_LIBRARIES}"
  )
endif()

add_library(redirect SHARED ./src/redirect.c)
target_link_libraries(redirect PRIVATE Lua::Lua)

set_target_properties(redirect
    PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_SOURCE_DIR}/lib"
)
