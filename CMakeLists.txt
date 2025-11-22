cmake_minimum_required(VERSION 3.11)

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

# Common properties for lua C libraries
add_library(lua_clib INTERFACE)
target_link_libraries(lua_clib INTERFACE Lua::Lua)
target_compile_features(lua_clib INTERFACE c_std_99)

if (MSVC)
	target_compile_options(lua_clib INTERFACE "/Wall" "/WX")
else()
	target_compile_options(lua_clib INTERFACE "-Wall" "-Werror" "-Wpedantic")
endif()

# Library targets

add_library(tomlc17 STATIC "./src/tomlc17.c")
set_target_properties(tomlc17 PROPERTIES POSITION_INDEPENDENT_CODE TRUE)
target_compile_features(tomlc17 PRIVATE c_std_99)
target_compile_definitions(tomlc17 PRIVATE _CRT_SECURE_NO_WARNINGS)

if (MSVC)
	# MVSC /Wall doesn't like tomlc17 unfortunately :(
	target_compile_options(tomlc17 PRIVATE "/W0")
endif()

add_library(pyproject MODULE ./src/pyproject.c)
set_target_properties(pyproject PROPERTIES PREFIX "_")
target_include_directories(pyproject PRIVATE ./src/)
target_link_libraries(pyproject PRIVATE lua_clib tomlc17)

install(TARGETS pyproject DESTINATION ./python_tools/meta/)

option(BUILD_REDIRECTLIB "Build testing utility library" OFF)

if (BUILD_REDIRECTLIB)
	add_library(redirect MODULE ./src/redirect.c)
	set_target_properties(redirect PROPERTIES PREFIX "_")
	target_compile_definitions(redirect PRIVATE _CRT_NONSTDC_NO_WARNINGS)
	target_link_libraries(redirect PRIVATE lua_clib)

	install(TARGETS redirect DESTINATION ./test/utils/)
endif()
