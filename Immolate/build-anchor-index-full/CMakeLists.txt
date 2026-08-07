cmake_minimum_required(VERSION 3.20)
project(BrainstormAnchorIndex LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(IMMOLATE_ROOT "${CMAKE_CURRENT_LIST_DIR}/..")

add_executable(anchor_index_builder
    anchor_index_builder.cpp
    ${IMMOLATE_ROOT}/src/items.cpp
    ${IMMOLATE_ROOT}/src/arbitrary_negative_batch.cpp
    ${IMMOLATE_ROOT}/src/negative_blueprint_batch.cpp
    ${IMMOLATE_ROOT}/src/opening_batch.cpp
    ${IMMOLATE_ROOT}/src/opening_batch_avx2.cpp
    ${IMMOLATE_ROOT}/src/opening_batch_avx512.cpp
    ${IMMOLATE_ROOT}/src/rng.cpp
    ${IMMOLATE_ROOT}/src/search.cpp
    ${IMMOLATE_ROOT}/src/seed.cpp
    ${IMMOLATE_ROOT}/src/seed_anchor_index.cpp
    ${IMMOLATE_ROOT}/src/util.cpp
    ${IMMOLATE_ROOT}/src/functions.cpp
)

target_include_directories(anchor_index_builder PRIVATE ${IMMOLATE_ROOT}/src)
target_compile_definitions(anchor_index_builder PRIVATE
    BUILDING_DLL
    BRAINSTORM_OPENING_BATCH_AVX2
    BRAINSTORM_OPENING_BATCH_AVX512
)

if(MSVC)
    target_compile_options(anchor_index_builder PRIVATE /Ox /fp:strict)
else()
    target_compile_options(anchor_index_builder PRIVATE
        -O3 -g -Wall -Wextra -Wpedantic -Wno-c++17-extensions
        -ffp-contract=off -fno-fast-math -march=native
    )
endif()

if(MINGW)
    set_source_files_properties(
        ${IMMOLATE_ROOT}/src/opening_batch_avx2.cpp
        PROPERTIES COMPILE_OPTIONS "-mavx2;-mno-avx512f;-mstackrealign"
    )
    set_source_files_properties(
        ${IMMOLATE_ROOT}/src/opening_batch_avx512.cpp
        PROPERTIES COMPILE_OPTIONS "-mavx512f;-mstackrealign"
    )
endif()

target_link_libraries(anchor_index_builder PRIVATE bcrypt)
