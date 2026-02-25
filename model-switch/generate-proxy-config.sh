#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${CLAUDE_SWITCHER_ENV:-$SCRIPT_DIR/.env.local}"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

: "${NVIDIA_API_KEY:?NVIDIA_API_KEY is required in $ENV_FILE}"
: "${KIMI_MODEL:=moonshotai/kimi-k2.5}"
: "${NVIDIA_PROXY_PORT:=3002}"
: "${NVIDIA_PROXY_CONFIG:=$HOME/.claude-nvidia-proxy/config.json}"

mkdir -p "$(dirname "$NVIDIA_PROXY_CONFIG")"

cat > "$NVIDIA_PROXY_CONFIG" <<JSON
{
  "nvidia_url": "https://integrate.api.nvidia.com/v1/chat/completions",
  "nvidia_base_url": "https://integrate.api.nvidia.com/v1",
  "nvidia_key": "${NVIDIA_API_KEY}",
  "port": ${NVIDIA_PROXY_PORT},
  "models": {
    "${KIMI_MODEL}": {
      "max_tokens": 8192,
      "context_window": 256000
    }
  }
}
JSON

chmod 600 "$NVIDIA_PROXY_CONFIG"
echo "Generated $NVIDIA_PROXY_CONFIG"
