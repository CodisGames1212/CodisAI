cmake_minimum_required(VERSION 3.22)
project(codisai LANGUAGES C CXX)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/.gdignore" "")

include(FetchContent)
if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Release CACHE STRING "Build configuration" FORCE)
endif()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

set(GODOT_CPP_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GODOT_CPP_SYSTEM_HEADERS ON CACHE BOOL "" FORCE)
set(GODOT_CPP_WARNING_AS_ERROR OFF CACHE BOOL "" FORCE)
set(GODOT_ENABLE_HOT_RELOAD OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
if(ANDROID)
	# The NDK OpenMP runtime is a separate shared library that Godot does
	# not automatically package. llama.cpp already provides CPU threading.
	set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
endif()

FetchContent_Declare(godot-cpp
	GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
	GIT_TAG godot-4.5-stable
	GIT_SHALLOW TRUE)
FetchContent_Declare(llama-cpp
	GIT_REPOSITORY https://github.com/ggerganov/llama.cpp.git
	GIT_TAG b3450
	GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(godot-cpp llama-cpp)

add_library(codisai SHARED
	codisai_native.cpp
	codisai_native.h
	register_types.cpp)
target_link_libraries(codisai PRIVATE godot::cpp llama)
target_include_directories(codisai PRIVATE ${llama-cpp_SOURCE_DIR}/include)

if(WIN32)
	set(CODISAI_PLATFORM windows)
elseif(APPLE)
	set(CODISAI_PLATFORM macos)
elseif(UNIX)
	set(CODISAI_PLATFORM linux)
else()
	message(FATAL_ERROR "Unsupported platform: ${CMAKE_SYSTEM_NAME}")
endif()

if(CMAKE_CONFIGURATION_TYPES)
	set(CODISAI_BUILD_TYPE "$<IF:$<CONFIG:Debug>,debug,release>")
elseif(CMAKE_BUILD_TYPE MATCHES "^[Dd][Ee][Bb][Uu][Gg]$")
	set(CODISAI_BUILD_TYPE debug)
else()
	set(CODISAI_BUILD_TYPE release)
endif()

if(ANDROID)
	set(CODISAI_PLATFORM android)
	if(ANDROID_ABI STREQUAL "arm64-v8a")
		set(CODISAI_ARCH arm64)
	elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
		set(CODISAI_ARCH arm32)
	elseif(ANDROID_ABI STREQUAL "x86_64")
		set(CODISAI_ARCH x86_64)
	elseif(ANDROID_ABI STREQUAL "x86")
		set(CODISAI_ARCH x86_32)
	else()
		message(FATAL_ERROR "Unsupported Android ABI: ${ANDROID_ABI}")
	endif()
elseif(CMAKE_OSX_ARCHITECTURES)
	list(LENGTH CMAKE_OSX_ARCHITECTURES OSX_ARCH_COUNT)
	if(OSX_ARCH_COUNT GREATER 1)
		message(FATAL_ERROR "Build macOS architectures separately; universal binaries are not mapped by the current GDExtension manifest.")
	endif()
	set(CODISAI_ARCH ${CMAKE_OSX_ARCHITECTURES})
elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
	if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(ARM64|arm64|aarch64)$")
		set(CODISAI_ARCH arm64)
	else()
		set(CODISAI_ARCH x86_64)
	endif()
else()
	set(CODISAI_ARCH x86_32)
endif()

set_target_properties(codisai PROPERTIES
	OUTPUT_NAME "codisai.${CODISAI_PLATFORM}.template_${CODISAI_BUILD_TYPE}.${CODISAI_ARCH}"
	LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../bin/${CODISAI_PLATFORM}"
	RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../bin/${CODISAI_PLATFORM}"
	ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib")

if(CMAKE_CONFIGURATION_TYPES)
	foreach(configuration DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
		set_target_properties(codisai PROPERTIES
			RUNTIME_OUTPUT_DIRECTORY_${configuration} "${CMAKE_CURRENT_SOURCE_DIR}/../bin/${CODISAI_PLATFORM}"
			LIBRARY_OUTPUT_DIRECTORY_${configuration} "${CMAKE_CURRENT_SOURCE_DIR}/../bin/${CODISAI_PLATFORM}")
	endforeach()
endif()

if(WIN32)
	set_target_properties(codisai PROPERTIES PREFIX "")
endif()
