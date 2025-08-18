# Enhanced CMakeLists.txt for libgphoto2 integration in Flutter macOS
cmake_minimum_required(VERSION 3.19)
project(Runner LANGUAGES C CXX OBJC OBJCXX)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Configure build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Find required packages
find_package(PkgConfig REQUIRED)

# Find libgphoto2 with version check
pkg_check_modules(GPHOTO2 REQUIRED libgphoto2>=2.5.0)

if(NOT GPHOTO2_FOUND)
    message(FATAL_ERROR "libgphoto2 not found. Install with: brew install libgphoto2")
endif()

message(STATUS "✅ Found libgphoto2 version: ${GPHOTO2_VERSION}")
message(STATUS "📁 Include dirs: ${GPHOTO2_INCLUDE_DIRS}")
message(STATUS "📚 Library dirs: ${GPHOTO2_LIBRARY_DIRS}")
message(STATUS "🔗 Libraries: ${GPHOTO2_LIBRARIES}")

# Detect architecture
if(CMAKE_OSX_ARCHITECTURES)
    set(TARGET_ARCH ${CMAKE_OSX_ARCHITECTURES})
else()
    execute_process(COMMAND uname -m OUTPUT_VARIABLE TARGET_ARCH OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()
message(STATUS "🏗️  Target architecture: ${TARGET_ARCH}")

# Set deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.14")

# Include directories
include_directories(${GPHOTO2_INCLUDE_DIRS})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/Runner)

# Link directories
link_directories(${GPHOTO2_LIBRARY_DIRS})

# Compiler flags
add_compile_options(${GPHOTO2_CFLAGS_OTHER})

# Add debug/release specific flags
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_compile_options(-DDEBUG=1 -g -O0)
    message(STATUS "🐛 Debug build enabled")
else()
    add_compile_options(-DNDEBUG=1 -O2)
    message(STATUS "🚀 Release build enabled")
endif()

# Source files
set(LIBGPHOTO2_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/Runner/LibGPhoto2Native.c
)

# Check if source file exists
foreach(SOURCE ${LIBGPHOTO2_SOURCES})
    if(NOT EXISTS ${SOURCE})
        message(WARNING "⚠️  Source file not found: ${SOURCE}")
    else()
        message(STATUS "✅ Found source: ${SOURCE}")
    endif()
endforeach()

# Create static library
add_library(libgphoto2_native STATIC ${LIBGPHOTO2_SOURCES})

# Set target properties
set_target_properties(libgphoto2_native PROPERTIES
    C_STANDARD 99
    C_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
)

# Include directories for the target
target_include_directories(libgphoto2_native PRIVATE
    ${GPHOTO2_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}/Runner
)

# Link libraries
target_link_libraries(libgphoto2_native 
    ${GPHOTO2_LIBRARIES}
    pthread  # Required for threading
)

# Compiler-specific options
target_compile_options(libgphoto2_native PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-unused-variable
    -fPIC
    $<$<CONFIG:Debug>:-g -O0>
    $<$<CONFIG:Release>:-O2 -DNDEBUG>
)

# Create a target for copying the library to Flutter build (when directory exists)
add_custom_command(TARGET libgphoto2_native POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/../../../build/macos/Build/Products/$<CONFIG>/
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:libgphoto2_native>
        ${CMAKE_BINARY_DIR}/../../../build/macos/Build/Products/$<CONFIG>/
    COMMENT "📦 Copying libgphoto2_native to Flutter build directory"
)

# Print build summary
message(STATUS "")
message(STATUS "🎯 libgphoto2 Integration Summary:")
message(STATUS "   📋 Project: ${PROJECT_NAME}")
message(STATUS "   🏗️  Architecture: ${TARGET_ARCH}")
message(STATUS "   📦 Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "   📚 libgphoto2: ${GPHOTO2_VERSION}")
message(STATUS "   🎯 Target: libgphoto2_native static library")
message(STATUS "")

# Installation rules
install(TARGETS libgphoto2_native
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    COMPONENT libgphoto2_native
)

# Install headers for development
install(FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/Runner/LibGPhoto2Native.h
    DESTINATION include
    COMPONENT libgphoto2_native
    OPTIONAL
)