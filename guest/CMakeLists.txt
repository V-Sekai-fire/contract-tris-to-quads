cmake_minimum_required(VERSION 3.25)
project(tris_to_quads_guest C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_BUILD_TYPE MinSizeRel)

add_executable(tris_to_quads.elf main.c)
target_include_directories(tris_to_quads.elf PRIVATE ${CMAKE_SOURCE_DIR}/../api)
target_link_options(tris_to_quads.elf PRIVATE -static -Wl,--strip-debug)
