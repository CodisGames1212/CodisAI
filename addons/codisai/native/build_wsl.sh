#!/usr/bin/env bash
set -euo pipefail

NATIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ROOT="${CODISAI_BUILD_ROOT:-${HOME}/.cache/codisai/build}"
FETCHCONTENT_DIR="${BUILD_ROOT}/_deps"
ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-${HOME}/Android/android-ndk-r28c}"
WINDOWS_ANDROID_NDK_ROOT="${WINDOWS_ANDROID_NDK_ROOT:-/mnt/c/Users/Admin/AppData/Local/Android/Sdk/ndk/27.2.12479018}"
ANDROID_TOOLCHAIN="${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-26}"
PARALLEL_JOBS="${CMAKE_BUILD_PARALLEL_LEVEL:-2}"

for tool in cmake git; do
	command -v "${tool}" >/dev/null || { echo "Missing required tool: ${tool}" >&2; exit 1; }
done

build_target() {
	local name="$1"
	local configuration="$2"
	shift 2
	local build_dir="${BUILD_ROOT}/${name}-${configuration,,}"
	cmake -S "${NATIVE_DIR}" -B "${build_dir}" \
		-DFETCHCONTENT_BASE_DIR="${FETCHCONTENT_DIR}" \
		-DCMAKE_BUILD_TYPE="${configuration}" \
		"$@"
	cmake --build "${build_dir}" --config "${configuration}" --parallel "${PARALLEL_JOBS}"
}

if [[ ! -f "${ANDROID_TOOLCHAIN}" ]]; then
	if [[ -f "${WINDOWS_ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake" ]]; then
		echo "Found a Windows-hosted Android NDK at ${WINDOWS_ANDROID_NDK_ROOT}; WSL requires Linux NDK binaries." >&2
	else
		echo "Android NDK not found at ${ANDROID_NDK_ROOT}. Set ANDROID_NDK_ROOT to a Linux-hosted NDK." >&2
	fi
	echo "Linux and Android builds were not started. Install a Linux NDK inside WSL or run Android builds from Windows." >&2
	exit 1
fi
if [[ ! -x "${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ]]; then
	echo "Android NDK clang toolchain is missing under ${ANDROID_NDK_ROOT}." >&2
	exit 1
fi

build_target linux-x86_64 Release

for abi in arm64-v8a armeabi-v7a x86_64 x86; do
	for configuration in Debug Release; do
		build_target "android-${abi}" "${configuration}" \
			-DCMAKE_TOOLCHAIN_FILE="${ANDROID_TOOLCHAIN}" \
			-DANDROID_ABI="${abi}" \
			-DANDROID_PLATFORM="${ANDROID_PLATFORM}" \
			-DANDROID_STL=c++_static
	done
done

printf '\nLinux Release and Android Debug/Release libraries are in %s/bin/\n' "${NATIVE_DIR}/.."
