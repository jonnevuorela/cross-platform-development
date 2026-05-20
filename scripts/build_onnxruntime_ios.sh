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

# Copy the built static library
# Search for monolithic .a, or individual .a, or framework binary
LIB=$(find "$BUILD_OUTPUT" -maxdepth 4 \( -name "libonnxruntime*.a" -o -path "*/onnxruntime.framework/onnxruntime" \) | head -1)
if [ -n "$LIB" ]; then
  cp "$LIB" "$OUT_DIR/libonnxruntime.a"
else
  echo "Error: static library not found in $BUILD_OUTPUT"
  find "$BUILD_OUTPUT" -maxdepth 4 \( -name "*.a" -o -name "onnxruntime" -type f \)
  exit 1
fi

echo ""
echo "Done. Built library at:"
ls -lh "$OUT_DIR/libonnxruntime.a"
echo ""
echo "Now rebuild the Flutter app. The iOS Rust build will link this custom library."
