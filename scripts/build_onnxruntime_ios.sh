#!/usr/bin/env bash
set -euo pipefail

# Builds ONNX Runtime from source for iOS (arm64).
# The pre-built iOS binary from pyke's CDN crashes during Environment::Initialize
# on device (known ONNX Runtime iOS bug). Building from source avoids the crash.
#
# Prerequisites: Xcode, cmake, python3
#   xcode-select --install
#   brew install cmake
#
# Run once before first iOS build:
#   ./scripts/build_onnxruntime_ios.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/app/rust/onnxruntime_ios"
ORT_VERSION="v1.24.2"
BUILD_DIR="$REPO_ROOT/.build/onnxruntime"

rm -rf "$BUILD_DIR"

echo "Building ONNX Runtime $ORT_VERSION for iOS (arm64)..."
echo "Output: $OUT_DIR"
echo "Build dir: $BUILD_DIR"

command -v cmake >/dev/null 2>&1 || { echo "Error: cmake not found. Install with: brew install cmake"; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "Error: Xcode not found. Install with: xcode-select --install"; exit 1; }

mkdir -p "$OUT_DIR" "$BUILD_DIR"

cd "$BUILD_DIR"
git clone --depth 1 --branch "$ORT_VERSION" https://github.com/microsoft/onnxruntime.git
cd onnxruntime

./build.sh \
  --config RelWithDebInfo \
  --use_xcode \
  --ios \
  --apple_sysroot iphoneos \
  --osx_arch arm64 \
  --apple_deploy_target 15.0 \
  --use_xnnpack \
  --parallel \
  --skip_tests \
  --compile_no_warning_as_error \
  --cmake_extra_defines CMAKE_POLICY_VERSION_MINIMUM=3.5 \
  --cmake_extra_defines onnxruntime_BUILD_UNIT_TESTS=OFF

BUILD_OUTPUT="build/iOS/RelWithDebInfo"

# Find all static libraries produced by the build
ARCHIVES=()
while IFS= read -r f; do
  ARCHIVES+=("$f")
done < <(find "$BUILD_OUTPUT" -name "*.a")

if [ ${#ARCHIVES[@]} -eq 0 ]; then
  echo "Error: no .a files found in $BUILD_OUTPUT"
  find "$BUILD_OUTPUT" -type f
  exit 1
fi

echo "Merging ${#ARCHIVES[@]} static libraries into one..."
printf "  %s\n" "${ARCHIVES[@]}"
echo "---"

libtool -static -o "$OUT_DIR/libonnxruntime.a" "${ARCHIVES[@]}"

echo ""
echo "Done. Merged library at:"
file "$OUT_DIR/libonnxruntime.a"
ls -lh "$OUT_DIR/libonnxruntime.a"
echo ""
echo "Now rebuild the Flutter app. The iOS Rust build will link this custom library."
