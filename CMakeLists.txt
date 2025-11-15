cmake_minimum_required(VERSION 3.14)

project(python_tools C)

# See: https://cmake.org/cmake/help/latest/module/FindLua.html
find_package(Lua 5.1 REQUIRED)
if(NOT TARGET Lua::Lua)
	add_library(Lua::Lua INTERFACE IMPORTED)
	target_include_directories(Lua::Lua INTERFACE "${LUA_INCLUDE_DIR}")
	# On unix systems, the linker can resolve symbols at runtime, so there's no
	# need to link against `.a` files.
	if(${WIN32})
		target_link_libraries(Lua::Lua INTERFACE "${LUA_LIBRARY}")
	endif()
endif()

add_library(redirect SHARED ./src/redirect.c)
target_compile_definitions(redirect PRIVATE _CRT_NONSTDC_NO_WARNINGS)
target_link_libraries(redirect PRIVATE Lua::Lua)

install(TARGETS redirect DESTINATION ./lib/test/utils/)

add_library(pyproject SHARED ./src/pyproject.c ./src/tomlc17.c)
target_compile_definitions(pyproject PRIVATE _CRT_SECURE_NO_WARNINGS)
target_include_directories(pyproject PRIVATE ./src/)
target_link_libraries(pyproject PRIVATE Lua::Lua)

install(TARGETS pyproject DESTINATION ./lib/python_tools/meta/)
