# One-exe launcher (see launcher.cpp). Built by tool/release/pack_launcher.ps1.
cmake_minimum_required(VERSION 3.15)
project(tidewater_launcher LANGUAGES CXX RC)

# Static CRT: the MSVC runtime DLLs live inside the payload, so the launcher itself must not need them.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")

set(ICON "${CMAKE_CURRENT_SOURCE_DIR}/../../../windows/runner/resources/app_icon.ico")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/launcher.rc" "1 ICON \"${ICON}\"\n")

add_executable(tidewater_launcher WIN32 launcher.cpp "${CMAKE_CURRENT_BINARY_DIR}/launcher.rc")
target_compile_features(tidewater_launcher PRIVATE cxx_std_17)
target_compile_definitions(tidewater_launcher PRIVATE UNICODE _UNICODE)
target_compile_options(tidewater_launcher PRIVATE /W4 /utf-8)
target_link_libraries(tidewater_launcher PRIVATE shell32)
