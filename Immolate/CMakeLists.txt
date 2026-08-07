cmake_minimum_required(VERSION 3.13)
project(Immolate LANGUAGES CXX)

# Keep normal builds portable. The native and PGO switches below are opt-in
# because their output is tied to the build machine and compiler respectively.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(
    BRAINSTORM_NATIVE_OPTIMIZATIONS
    "Tune generated code for the current machine (non-portable)"
    OFF
)
option(
    BRAINSTORM_REQUIRE_MEGA_INDEX_ASSETS
    "Fail configuration unless both complete Perkeo/Mega indexes and manifests exist"
    OFF
)
set(
    BRAINSTORM_PGO_PHASE "OFF" CACHE STRING
    "Profile-guided optimization phase: OFF, GENERATE, or USE"
)
set_property(
    CACHE BRAINSTORM_PGO_PHASE PROPERTY STRINGS OFF GENERATE USE
)
set(
    BRAINSTORM_PGO_PROFILE_DIR
    "${CMAKE_BINARY_DIR}/pgo-data"
    CACHE PATH
    "Directory shared by the GCC PGO GENERATE and USE phases"
)

string(TOUPPER "${BRAINSTORM_PGO_PHASE}" BRAINSTORM_PGO_PHASE)
set(
    BRAINSTORM_PGO_PHASE "${BRAINSTORM_PGO_PHASE}" CACHE STRING
    "Profile-guided optimization phase: OFF, GENERATE, or USE" FORCE
)
if(NOT BRAINSTORM_PGO_PHASE MATCHES "^(OFF|GENERATE|USE)$")
    message(FATAL_ERROR
        "BRAINSTORM_PGO_PHASE must be OFF, GENERATE, or USE")
endif()

# One interface target makes the numerical and profiling flags identical for
# the DLL, command-line tools, and regression tests. That matters for PGO:
# both compilation and linking must use the selected phase.
add_library(brainstorm_build_options INTERFACE)

if(MSVC)
    target_compile_options(
        brainstorm_build_options INTERFACE /Ox /fp:strict
    )
    if(BRAINSTORM_NATIVE_OPTIMIZATIONS)
        message(FATAL_ERROR
            "BRAINSTORM_NATIVE_OPTIMIZATIONS is only validated with GCC")
    endif()
    if(NOT BRAINSTORM_PGO_PHASE STREQUAL "OFF")
        message(FATAL_ERROR "Brainstorm's PGO pipeline is only validated with GCC")
    endif()
else()
    target_compile_options(
        brainstorm_build_options INTERFACE
        -O3
        -g
        -Wall
        -Wextra
        -Wpedantic
        -Wno-c++17-extensions
        # Seed generation must remain bit-for-bit equivalent to Lua. Native
        # tuning is safe only while contraction and fast-math remain disabled.
        -ffp-contract=off
        -fno-fast-math
    )
    if(WIN32)
        target_compile_options(brainstorm_build_options INTERFACE -gdwarf-3)
    endif()

    if(BRAINSTORM_NATIVE_OPTIMIZATIONS)
        if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            message(FATAL_ERROR
                "BRAINSTORM_NATIVE_OPTIMIZATIONS is only validated with GCC")
        endif()
        target_compile_options(
            brainstorm_build_options INTERFACE -march=native
        )
    endif()

    if(NOT BRAINSTORM_PGO_PHASE STREQUAL "OFF")
        if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            message(FATAL_ERROR "Brainstorm's PGO pipeline is only validated with GCC")
        endif()

        get_filename_component(
            BRAINSTORM_PGO_PROFILE_DIR
            "${BRAINSTORM_PGO_PROFILE_DIR}"
            ABSOLUTE
            BASE_DIR "${CMAKE_BINARY_DIR}"
        )
        file(TO_CMAKE_PATH
            "${BRAINSTORM_PGO_PROFILE_DIR}"
            BRAINSTORM_PGO_PROFILE_DIR
        )
        file(MAKE_DIRECTORY "${BRAINSTORM_PGO_PROFILE_DIR}")

        if(BRAINSTORM_PGO_PHASE STREQUAL "GENERATE")
            set(_brainstorm_pgo_options
                "-fprofile-generate=${BRAINSTORM_PGO_PROFILE_DIR}"
            )
        else()
            file(GLOB_RECURSE _brainstorm_profile_counters
                "${BRAINSTORM_PGO_PROFILE_DIR}/*.gcda")
            if(NOT _brainstorm_profile_counters)
                message(FATAL_ERROR
                    "PGO USE requested, but no .gcda counters exist in "
                    "${BRAINSTORM_PGO_PROFILE_DIR}. Run GENERATE and the "
                    "training workload first, without changing build paths.")
            endif()
            set(_brainstorm_pgo_options
                "-fprofile-use=${BRAINSTORM_PGO_PROFILE_DIR}"
                -fprofile-correction
                -fprofile-partial-training
                -Wno-missing-profile
            )
        endif()

        target_compile_options(
            brainstorm_build_options INTERFACE ${_brainstorm_pgo_options}
        )
        target_link_options(
            brainstorm_build_options INTERFACE ${_brainstorm_pgo_options}
        )
    endif()
endif()

# The opening Charm/Soul/Perkeo gate is always available through its scalar
# implementation. GCC x86 builds also carry isolated AVX2 and AVX-512 objects;
# the baseline dispatcher calls them only after OS-aware CPU detection.
set(BRAINSTORM_OPENING_BATCH_SOURCES src/opening_batch.cpp)
set(BRAINSTORM_OPENING_BATCH_DEFINITIONS)
set(BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_SOURCES
    src/negative_blueprint_batch.cpp
)
set(BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_DEFINITIONS)
set(BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_SOURCES
    src/arbitrary_negative_batch.cpp
)
set(BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_DEFINITIONS)
# The arbitrary-Negative batch intentionally ships scalar-only on Windows.
# Its multi-stream SIMD prototypes make MinGW emit aligned ymm/zmm spills even
# though the Windows ABI guarantees only 16-byte incoming stack alignment;
# the resulting fault is intermittent. Add SIMD objects only after an ABI-safe
# alignment wrapper is available.
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    include(CheckCXXSourceCompiles)
    check_cxx_source_compiles(
        "#if !defined(__i386__) && !defined(__x86_64__)\n#error not x86\n#endif\nint main() { return 0; }"
        BRAINSTORM_GNU_X86
    )
    if(BRAINSTORM_GNU_X86)
        list(APPEND BRAINSTORM_OPENING_BATCH_SOURCES
            src/opening_batch_avx2.cpp
            src/opening_batch_avx512.cpp
        )
        list(APPEND BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_SOURCES
            src/negative_blueprint_batch_avx2.cpp
            src/negative_blueprint_batch_avx512.cpp
        )
        list(APPEND BRAINSTORM_OPENING_BATCH_DEFINITIONS
            BRAINSTORM_OPENING_BATCH_AVX2
            BRAINSTORM_OPENING_BATCH_AVX512
        )
        list(APPEND BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_DEFINITIONS
            BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_AVX2
            BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_AVX512
        )
        set(_brainstorm_avx2_options -mavx2 -mno-avx512f)
        set(_brainstorm_avx512_options -mavx512f)
        if(WIN32)
            # MinGW otherwise assumes only the normal 16-byte Windows entry
            # alignment. Realign these isolated translation units before any
            # compiler-generated vector spills.
            list(APPEND _brainstorm_avx2_options -mstackrealign)
            list(APPEND _brainstorm_avx512_options -mstackrealign)
        endif()
        if(NOT BRAINSTORM_PGO_PHASE STREQUAL "OFF")
            # GCC/MinGW's profiling prologue can lose the realigned Windows
            # stack in these explicitly vectorized translation units.  That
            # corrupts aligned ymm/zmm spills during GENERATE (and has caused
            # profile-only crashes despite exact native-build parity).  Keep
            # PGO on the dispatcher, search, and authoritative verification
            # code, but compile the isolated SIMD kernels consistently
            # without instrumentation in both phases.
            list(APPEND _brainstorm_avx2_options -fno-profile-generate)
            list(APPEND _brainstorm_avx512_options -fno-profile-generate)
            if(BRAINSTORM_PGO_PHASE STREQUAL "USE")
                list(APPEND _brainstorm_avx2_options -fno-profile-use)
                list(APPEND _brainstorm_avx512_options -fno-profile-use)
            endif()
        endif()
        set_source_files_properties(
            src/opening_batch_avx2.cpp PROPERTIES
            COMPILE_OPTIONS "${_brainstorm_avx2_options}"
        )
        set_source_files_properties(
            src/opening_batch_avx512.cpp PROPERTIES
            COMPILE_OPTIONS "${_brainstorm_avx512_options}"
        )
        set_source_files_properties(
            src/negative_blueprint_batch_avx2.cpp PROPERTIES
            COMPILE_OPTIONS "${_brainstorm_avx2_options}"
        )
        set_source_files_properties(
            src/negative_blueprint_batch_avx512.cpp PROPERTIES
            COMPILE_OPTIONS "${_brainstorm_avx512_options}"
        )
    endif()
endif()

# Define sources for the library.
set(LIB_SOURCES
    src/functions.hpp
    src/instance.hpp
    src/immolate.cpp
    src/items.cpp
    ${BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_SOURCES}
    ${BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_SOURCES}
    ${BRAINSTORM_OPENING_BATCH_SOURCES}
    src/rng.cpp
    src/search.cpp
    src/seed.cpp
    src/seed_anchor_index.cpp
    src/util.cpp
    src/functions.cpp
)

add_library(${PROJECT_NAME} SHARED ${LIB_SOURCES})
target_link_libraries(
    ${PROJECT_NAME} PRIVATE brainstorm_build_options ${CMAKE_DL_LIBS}
)
target_compile_definitions(
    ${PROJECT_NAME} PRIVATE
    BUILDING_DLL
    ${BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_DEFINITIONS}
    ${BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_DEFINITIONS}
    ${BRAINSTORM_OPENING_BATCH_DEFINITIONS}
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    PREFIX ""
    RUNTIME_OUTPUT_NAME "${PROJECT_NAME}"
    ARCHIVE_OUTPUT_NAME "${PROJECT_NAME}"
)

# Release builds keep the trusted, generated rare-anchor asset beside the DLL,
# which is also where the runtime loader looks by default. The source checkout
# remains buildable before an offline index has been generated.
set(BRAINSTORM_ANCHOR_INDEX_ASSET
    "${CMAKE_CURRENT_SOURCE_DIR}/../Brainstorm/perkeo_invisible_anchor_v1.ids"
)
set(BRAINSTORM_DERIVED_ANCHOR_INDEX_ASSET
    "${CMAKE_CURRENT_SOURCE_DIR}/../Brainstorm/perkeo_invisible_ante2_invisible_anchor_v1.ids"
)
set(BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX_ASSET
    "${CMAKE_CURRENT_SOURCE_DIR}/../Brainstorm/charm_perkeo_mega_spectral_anchor_v1.ids"
)
set(BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX_ASSET
    "${CMAKE_CURRENT_SOURCE_DIR}/../Brainstorm/charm_perkeo_mega_naneinf_plasma_gold_v1.ids"
)
if(BRAINSTORM_REQUIRE_MEGA_INDEX_ASSETS)
    foreach(_brainstorm_required_mega_asset
            "${BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX_ASSET}"
            "${BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX_ASSET}")
        string(REGEX REPLACE "\\.ids$" ".manifest.json"
            _brainstorm_required_mega_manifest
            "${_brainstorm_required_mega_asset}")
        if(NOT EXISTS "${_brainstorm_required_mega_asset}")
            message(FATAL_ERROR
                "Required complete index is missing: ${_brainstorm_required_mega_asset}")
        endif()
        if(NOT EXISTS "${_brainstorm_required_mega_manifest}")
            message(FATAL_ERROR
                "Required index manifest is missing: ${_brainstorm_required_mega_manifest}")
        endif()
    endforeach()
endif()
foreach(_brainstorm_anchor_asset
        "${BRAINSTORM_ANCHOR_INDEX_ASSET}"
        "${BRAINSTORM_DERIVED_ANCHOR_INDEX_ASSET}"
        "${BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX_ASSET}"
        "${BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX_ASSET}")
if(EXISTS "${_brainstorm_anchor_asset}")
    string(REGEX REPLACE "\\.ids$" ".manifest.json"
        _brainstorm_anchor_manifest "${_brainstorm_anchor_asset}")
    add_custom_command(
        TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${_brainstorm_anchor_asset}"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>"
        COMMENT "Copying Brainstorm rare-anchor asset beside the DLL"
    )
    if(EXISTS "${_brainstorm_anchor_manifest}")
        add_custom_command(
            TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_brainstorm_anchor_manifest}"
                "$<TARGET_FILE_DIR:${PROJECT_NAME}>"
            COMMENT "Copying Brainstorm rare-anchor manifest beside the DLL"
        )
    endif()
endif()
endforeach()

include(GenerateExportHeader)
generate_export_header(${PROJECT_NAME}
    BASE_NAME IMMOLATE
    EXPORT_MACRO_NAME IMMOLATE_API
    EXPORT_FILE_NAME ImmolateExport.h
    STATIC_DEFINE IMMOLATE_BUILT_AS_STATIC
)

add_executable(immol src/main.cpp)
target_link_libraries(immol PRIVATE ${PROJECT_NAME} brainstorm_build_options)

# The training executable is intentionally present only in profile-generation
# builds. It runs the same exported DLL entry point used by the mod.
if(BRAINSTORM_PGO_PHASE STREQUAL "GENERATE")
    add_executable(brainstorm_pgo_train tools/brainstorm_pgo_train.cpp)
    target_include_directories(brainstorm_pgo_train PRIVATE src)
    # Only the DLL needs counters from this process. Leaving the tiny driver
    # uninstrumented also avoids generating a profile for a target that is
    # intentionally absent from the USE-phase build.
    target_link_libraries(brainstorm_pgo_train PRIVATE ${PROJECT_NAME})
endif()

include(CTest)
if(BUILD_TESTING)
    add_executable(brainstorm_benchmark
        tools/benchmark_brainstorm_v6.cpp
    )
    target_link_libraries(
        brainstorm_benchmark PRIVATE ${PROJECT_NAME} brainstorm_build_options
    )
    target_include_directories(brainstorm_benchmark PRIVATE src)

    add_executable(brainstorm_api_regression
        tests/brainstorm_api_regression.cpp
        src/seed.cpp
        src/util.cpp
    )
    target_link_libraries(
        brainstorm_api_regression PRIVATE
        ${PROJECT_NAME}
        brainstorm_build_options
    )
    target_include_directories(brainstorm_api_regression PRIVATE src)
    add_test(NAME brainstorm_api_regression COMMAND brainstorm_api_regression)

    add_executable(brainstorm_soul_scanner_regression
        tests/brainstorm_soul_scanner_regression.cpp
        src/items.cpp
        src/rng.cpp
        src/seed.cpp
        src/util.cpp
        src/functions.cpp
    )
    target_link_libraries(
        brainstorm_soul_scanner_regression PRIVATE brainstorm_build_options
    )
    target_include_directories(brainstorm_soul_scanner_regression PRIVATE src)
    add_test(
        NAME brainstorm_soul_scanner_regression
        COMMAND brainstorm_soul_scanner_regression
    )

    add_executable(brainstorm_joker_only_shop_regression
        tests/brainstorm_joker_only_shop_regression.cpp
        src/items.cpp
        src/rng.cpp
        src/seed.cpp
        src/util.cpp
        src/functions.cpp
    )
    target_link_libraries(
        brainstorm_joker_only_shop_regression PRIVATE brainstorm_build_options
    )
    target_include_directories(
        brainstorm_joker_only_shop_regression PRIVATE src
    )
    add_test(
        NAME brainstorm_joker_only_shop_regression
        COMMAND brainstorm_joker_only_shop_regression
    )

    add_executable(brainstorm_node_cache_regression
        tests/node_cache_regression.cpp
        src/seed.cpp
        src/util.cpp
    )
    target_link_libraries(
        brainstorm_node_cache_regression PRIVATE brainstorm_build_options
    )
    target_include_directories(
        brainstorm_node_cache_regression PRIVATE src
    )
    add_test(
        NAME brainstorm_node_cache_regression
        COMMAND brainstorm_node_cache_regression
    )

    add_executable(brainstorm_opening_batch_regression
        tests/opening_batch_regression.cpp
        ${BRAINSTORM_OPENING_BATCH_SOURCES}
        src/items.cpp
        src/rng.cpp
        src/seed.cpp
        src/util.cpp
        src/functions.cpp
    )
    target_link_libraries(
        brainstorm_opening_batch_regression PRIVATE brainstorm_build_options
    )
    target_compile_definitions(
        brainstorm_opening_batch_regression PRIVATE
        BRAINSTORM_OPENING_BATCH_TESTING
        ${BRAINSTORM_OPENING_BATCH_DEFINITIONS}
    )
    target_include_directories(
        brainstorm_opening_batch_regression PRIVATE src
    )
    add_test(
        NAME brainstorm_opening_batch_regression
        COMMAND brainstorm_opening_batch_regression
    )

    add_executable(brainstorm_negative_blueprint_batch_regression
        tests/negative_blueprint_batch_regression.cpp
        ${BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_SOURCES}
        src/items.cpp
        src/rng.cpp
        src/seed.cpp
        src/util.cpp
        src/functions.cpp
    )
    target_link_libraries(
        brainstorm_negative_blueprint_batch_regression PRIVATE
        brainstorm_build_options
    )
    target_compile_definitions(
        brainstorm_negative_blueprint_batch_regression PRIVATE
        ${BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_DEFINITIONS}
    )
    target_include_directories(
        brainstorm_negative_blueprint_batch_regression PRIVATE src
    )
    add_test(
        NAME brainstorm_negative_blueprint_batch_regression
        COMMAND brainstorm_negative_blueprint_batch_regression
    )

    add_executable(brainstorm_arbitrary_negative_batch_regression
        tests/arbitrary_negative_batch_regression.cpp
        ${BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_SOURCES}
        src/items.cpp
        src/rng.cpp
        src/seed.cpp
        src/util.cpp
        src/functions.cpp
    )
    target_link_libraries(
        brainstorm_arbitrary_negative_batch_regression PRIVATE
        brainstorm_build_options
    )
    target_compile_definitions(
        brainstorm_arbitrary_negative_batch_regression PRIVATE
        ${BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_DEFINITIONS}
    )
    target_include_directories(
        brainstorm_arbitrary_negative_batch_regression PRIVATE src
    )
    add_test(
        NAME brainstorm_arbitrary_negative_batch_regression
        COMMAND brainstorm_arbitrary_negative_batch_regression
    )

    add_executable(brainstorm_candidate_search_regression
        tests/candidate_search_regression.cpp
        src/seed.cpp
        src/util.cpp
    )
    target_link_libraries(
        brainstorm_candidate_search_regression PRIVATE
        brainstorm_build_options
    )
    target_include_directories(
        brainstorm_candidate_search_regression PRIVATE src
    )
    add_test(
        NAME brainstorm_candidate_search_regression
        COMMAND brainstorm_candidate_search_regression
    )

    add_executable(brainstorm_anchor_index_regression
        tests/anchor_index_regression.cpp
        src/seed_anchor_index.cpp
    )
    target_link_libraries(
        brainstorm_anchor_index_regression PRIVATE
        brainstorm_build_options ${CMAKE_DL_LIBS}
    )
    target_include_directories(
        brainstorm_anchor_index_regression PRIVATE src
    )

    add_executable(brainstorm_mega_index_route_regression
        tests/mega_index_route_regression.cpp
        src/seed.cpp
        src/util.cpp
    )
    target_link_libraries(
        brainstorm_mega_index_route_regression PRIVATE
        ${PROJECT_NAME} brainstorm_build_options
    )
    target_include_directories(
        brainstorm_mega_index_route_regression PRIVATE src
    )
    foreach(_brainstorm_anchor_case
            valid unsorted duplicate out_of_range truncated empty missing
            disabled)
        add_test(
            NAME brainstorm_anchor_index_${_brainstorm_anchor_case}
            COMMAND brainstorm_anchor_index_regression
                    ${_brainstorm_anchor_case}
        )
    endforeach()
    foreach(_brainstorm_new_anchor_prefix
            perkeo_mega perkeo_mega_naneinf)
        foreach(_brainstorm_anchor_case
                valid unsorted duplicate out_of_range truncated empty missing
                disabled)
            add_test(
                NAME brainstorm_anchor_index_${_brainstorm_new_anchor_prefix}_${_brainstorm_anchor_case}
                COMMAND brainstorm_anchor_index_regression
                        ${_brainstorm_new_anchor_prefix}_${_brainstorm_anchor_case}
            )
        endforeach()
    endforeach()
    if(EXISTS "${BRAINSTORM_ANCHOR_INDEX_ASSET}")
        add_test(
            NAME brainstorm_anchor_index_packaged
            COMMAND brainstorm_anchor_index_regression packaged
        )
    endif()
    if(EXISTS "${BRAINSTORM_DERIVED_ANCHOR_INDEX_ASSET}")
        add_test(
            NAME brainstorm_anchor_index_derived_packaged
            COMMAND brainstorm_anchor_index_regression derived_packaged
        )
    endif()
    if(EXISTS "${BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX_ASSET}")
        add_test(
            NAME brainstorm_anchor_index_perkeo_mega_packaged
            COMMAND brainstorm_anchor_index_regression perkeo_mega_packaged
        )
    endif()
    if(EXISTS "${BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX_ASSET}")
        add_test(
            NAME brainstorm_anchor_index_perkeo_mega_naneinf_packaged
            COMMAND brainstorm_anchor_index_regression
                    perkeo_mega_naneinf_packaged
        )
    endif()
    if(EXISTS "${BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX_ASSET}"
       AND EXISTS "${BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX_ASSET}")
        foreach(_brainstorm_mega_route_case
                packaged child_missing missing disabled corrupt priority_only
                later_deadline perkeo_later white_stake non_plasma_deck)
            add_test(
                NAME brainstorm_mega_index_route_${_brainstorm_mega_route_case}
                COMMAND brainstorm_mega_index_route_regression
                        ${_brainstorm_mega_route_case}
            )
        endforeach()
    endif()
endif()
