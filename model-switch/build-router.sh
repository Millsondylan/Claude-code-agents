#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/router-proxy/main.go"
OUT="${MODEL_ROUTER_BIN:-$HOME/bin/claude-model-router}"

mkdir -p "$(dirname "$OUT")"
go build -o "$OUT" "$SRC"
chmod +x "$OUT"
echo "Built $OUT"
