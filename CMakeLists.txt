cmake_minimum_required(VERSION 3.14)

project(python_tools C)

# Discover lua paths for linking...
foreach(var LUA_LIBDIR LUA_INCDIR LUA_LIBDIR_FILE)
	execute_process(
		COMMAND luarocks.bat config ${var}
		OUTPUT_VARIABLE ${var}
		OUTPUT_STRIP_TRAILING_WHITESPACE)
	message("${var}: ${${var}}")
endforeach()

add_library(redirect SHARED ./src/redirect.c)

target_include_directories(redirect PRIVATE ${LUA_INCDIR})
target_link_directories(redirect PRIVATE ${LUA_LIBDIR})
target_link_libraries(redirect PRIVATE ${LUA_LIBDIR_FILE})

set_target_properties(redirect
    PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_SOURCE_DIR}/lib"
)

