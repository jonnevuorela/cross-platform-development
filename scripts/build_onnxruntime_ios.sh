#!/usr/bin/env bash
set -euo pipefail

# Builds ONNX Runtime from source for iOS (arm64).
# The pre-built iOS binary from pyke's CDN crashes during Environment::Initialize
# on device (known ONNX Runtime iOS bug). Building from source with minimal config
# and --disable_ml_ops avoids the crash.
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
BUILD_DIR="$(mktemp -d)"

trap 'rm -rf "$BUILD_DIR"' EXIT

echo "Building ONNX Runtime $ORT_VERSION for iOS (arm64)..."
echo "Output: $OUT_DIR"

command -v cmake >/dev/null 2>&1 || { echo "Error: cmake not found. Install with: brew install cmake"; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "Error: Xcode not found. Install with: xcode-select --install"; exit 1; }

mkdir -p "$OUT_DIR"

cd "$BUILD_DIR"
git clone --depth 1 --branch "$ORT_VERSION" https://github.com/microsoft/onnxruntime.git
cd onnxruntime

./build.sh \
  --config RelWithDebInfo \
  --use_xcode \
  --ios \
  --ios_sysroot iphoneos \
  --osx_arch arm64 \
  --apple_deploy_target 15.0 \
  --use_xnnpack \
  --minimal_build extended \
  --disable_ml_ops \
  --disable_exceptions \
  --skip_tests

BUILD_OUTPUT="build/iOS/RelWithDebInfo"

# Copy the built static library
LIB=$(find "$BUILD_OUTPUT" -name "libonnxruntime*.a" -maxdepth 3 | head -1)
if [ -n "$LIB" ]; then
  cp "$LIB" "$OUT_DIR/libonnxruntime.a"
elif [ -f "$BUILD_OUTPUT/onnxruntime.framework/onnxruntime" ]; then
  cp "$BUILD_OUTPUT/onnxruntime.framework/onnxruntime" "$OUT_DIR/libonnxruntime.a"
else
  echo "Error: libonnxruntime.a not found in $BUILD_OUTPUT"
  find "$BUILD_OUTPUT" -name "*.a" -maxdepth 4
  exit 1
fi

echo ""
echo "Done. Built library at:"
ls -lh "$OUT_DIR/libonnxruntime.a"
echo ""
echo "Now rebuild the Flutter app. The iOS Rust build will link this custom library."
