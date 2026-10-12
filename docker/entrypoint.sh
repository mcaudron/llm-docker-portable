#!/bin/sh
set -eu

if [ ! -r "$MODEL" ]; then
  echo "Model not found or unreadable: $MODEL" >&2
  exit 1
fi

# llama.cpp uses 0 for automatic thread selection.
set -- llama-server \
  --model "$MODEL" \
  --alias "$MODEL_ID" \
  --host "$HOST" \
  --port "$PORT" \
  --ctx-size "$CONTEXT_SIZE" \
  --threads "$THREADS" \
  --parallel "$PARALLEL" \
  --n-gpu-layers "$N_GPU_LAYERS"

if [ -n "${FLASH_ATTN:-}" ]; then
  set -- "$@" --flash-attn "$FLASH_ATTN"
fi

if [ -n "$API_KEY" ]; then
  set -- "$@" --api-key "$API_KEY"
fi

exec "$@"
