#!/bin/sh
# The CMake options a candidate patch selection turns on, as a function a
# builder sources and a unit test drives directly.
#
# A candidate that carries its own CMake option states that option in both
# directions. CMake writes an option into CMakeCache.txt at its first
# configuration and keeps the cached value across every later configuration of
# the same build directory, so a selection that omits the flag inherits the
# previous run's value rather than the option's declared default. A build
# directory configured once with the candidate selected would therefore compile
# the candidate's source into every later build of that directory while the
# manifest recorded no candidate selection, which corrupts the control and the
# artifact identity together.
#
# The file defines one function and touches no state, so sourcing it is safe
# from a builder that has already parsed its own arguments.

# Print the candidate-derived CMake options for one QWEN_LLAMA_CANDIDATE_SELECT
# value, one option per line, in ledger order. The selection is matched whole
# against a blank-delimited name so a patch name that is a substring of another
# never matches.
qwen_candidate_cmake_flags() {
    qwen_candidate_selection=" $1 "

    # The int24 candidate rewrites the q8_1 mat-vec shader and the pipeline
    # table that names it behind GGML_VULKAN_INT24_DOT, so the option follows
    # the patch rather than the preset name: a tree carrying the patch without
    # the flag compiles the arm out and measures the production shape under the
    # candidate's name.
    case $qwen_candidate_selection in
        *" llama-vulkan-q4k-int24-mmvq.patch "*)
            printf -- '-DGGML_VULKAN_INT24_DOT=ON\n'
            ;;
        *)
            printf -- '-DGGML_VULKAN_INT24_DOT=OFF\n'
            ;;
    esac
}
