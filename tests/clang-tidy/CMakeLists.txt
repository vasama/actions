cmake_minimum_required(VERSION 4.0)
project(vsm-actions-test-clang-tidy)
add_library(test_clang_tidy clang_tidy.cpp)
target_compile_features(test_clang_tidy PRIVATE cxx_std_20)
