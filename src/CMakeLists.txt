# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(vtzero_dart_library VERSION 0.0.1 LANGUAGES C CXX)

# C++14 required for vtzero
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Include directories for vtzero and protozero
include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vtzero/include
  ${CMAKE_CURRENT_SOURCE_DIR}/../third_party/protozero/include
)

add_library(vtzero_dart SHARED
  "vtzero_wrapper.cpp"
)

set_target_properties(vtzero_dart PROPERTIES
  PUBLIC_HEADER vtzero_dart.h
  OUTPUT_NAME "vtzero_dart"
)

target_compile_definitions(vtzero_dart PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(vtzero_dart PRIVATE "-Wl,-z,max-page-size=16384")
endif()
