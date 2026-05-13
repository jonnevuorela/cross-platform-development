#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL_DIR="$REPO_ROOT/app/assets/models/onnx"
HF_REPO="HuggingFaceTB/SmolLM3-3B-ONNX"
TMPDIR="$(mktemp -d)"

echo "Downloading SmolLM3 models to $MODEL_DIR"
mkdir -p "$MODEL_DIR" "$TMPDIR"

if command -v hf &>/dev/null; then
  hf download "$HF_REPO" \
    --include "onnx/model_fp16.onnx" \
    --include "onnx/model_fp16.onnx_data" \
    --include "onnx/model_q4.onnx" \
    --include "onnx/model_q4.onnx_data" \
    --include "tokenizer.json" \
    --local-dir "$TMPDIR"
elif command -v huggingface-cli &>/dev/null; then
  huggingface-cli download "$HF_REPO" \
    --include "onnx/model_fp16.onnx" \
    --include "onnx/model_fp16.onnx_data" \
    --include "onnx/model_q4.onnx" \
    --include "onnx/model_q4.onnx_data" \
    --include "tokenizer.json" \
    --local-dir "$TMPDIR"
else
  echo "Error: neither 'hf' nor 'huggingface-cli' found."
  echo "Install with: pip install -U \"huggingface_hub[cli]\""
  exit 1
fi
cp "$TMPDIR"/onnx/*.onnx* "$MODEL_DIR"/
cp "$TMPDIR"/tokenizer.json "$MODEL_DIR"/
rm -rf "$TMPDIR"

echo ""
echo "Done. Files in $MODEL_DIR:"
ls -lh "$MODEL_DIR"
