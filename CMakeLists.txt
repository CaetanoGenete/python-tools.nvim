cmake_minimum_required(VERSION 3.14)

project(python_tools C)

find_package(Lua 5.1 REQUIRED)

add_library(redirect SHARED ./src/redirect.c)
target_link_libraries(redirect PRIVATE ${LUA_LIBRARY})
target_include_directories(redirect PRIVATE ${LUA_INCLUDE_DIR})

set_target_properties(redirect
    PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_SOURCE_DIR}/lib"
)
