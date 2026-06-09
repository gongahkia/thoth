cmake_minimum_required(VERSION 3.24)

project(thoth
    VERSION 0.1.0
    DESCRIPTION "Top-down block automation sandbox built with C++ and raylib"
    LANGUAGES CXX)

option(THOTH_BUILD_APP "Build the raylib desktop application" ON)
option(THOTH_BUILD_TESTS "Build headless simulation tests" ON)
option(THOTH_BUILD_BENCHMARKS "Build headless simulation benchmarks" ON)
option(THOTH_FETCH_RAYLIB "Fetch raylib from source when no package is installed" ON)

if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(thoth_core
    src/thoth/core/deterministic_random.cpp
    src/thoth/game/inventory.cpp
    src/thoth/game/replay.cpp
    src/thoth/game/registry.cpp
    src/thoth/game/save.cpp
    src/thoth/game/simulation.cpp
    src/thoth/game/world.cpp)

target_include_directories(thoth_core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include)

target_compile_features(thoth_core PUBLIC cxx_std_17)

if(MSVC)
    target_compile_options(thoth_core PRIVATE /W4 /permissive-)
else()
    target_compile_options(thoth_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

if(THOTH_BUILD_APP)
    find_package(raylib QUIET)

    if(NOT raylib_FOUND AND THOTH_FETCH_RAYLIB)
        include(FetchContent)
        set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
        set(BUILD_GAMES OFF CACHE BOOL "" FORCE)
        FetchContent_Declare(
            raylib
            URL https://github.com/raysan5/raylib/archive/refs/tags/6.0.tar.gz)
        FetchContent_MakeAvailable(raylib)
    endif()

    if(NOT TARGET raylib)
        message(FATAL_ERROR "raylib was not found. Install raylib or configure with -DTHOTH_BUILD_APP=OFF.")
    endif()

    add_executable(thoth_raylib
        src/app/main.cpp)

    target_link_libraries(thoth_raylib
        PRIVATE
            thoth_core
            raylib)

    if(MSVC)
        target_compile_options(thoth_raylib PRIVATE /W4 /permissive-)
    else()
        target_compile_options(thoth_raylib PRIVATE -Wall -Wextra -Wpedantic)
    endif()
endif()

if(THOTH_BUILD_TESTS)
    enable_testing()

    add_executable(thoth_tests
        tests/test_world.cpp)

    target_link_libraries(thoth_tests PRIVATE thoth_core)

    if(MSVC)
        target_compile_options(thoth_tests PRIVATE /W4 /permissive-)
    else()
        target_compile_options(thoth_tests PRIVATE -Wall -Wextra -Wpedantic)
    endif()

    add_test(NAME thoth_tests COMMAND thoth_tests)
endif()

if(THOTH_BUILD_BENCHMARKS)
    add_executable(thoth_benchmark
        benchmarks/simulation_benchmark.cpp)

    target_link_libraries(thoth_benchmark PRIVATE thoth_core)

    if(MSVC)
        target_compile_options(thoth_benchmark PRIVATE /W4 /permissive-)
    else()
        target_compile_options(thoth_benchmark PRIVATE -Wall -Wextra -Wpedantic)
    endif()
endif()
