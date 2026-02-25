# shellcheck shell=bash

export CLAUDE_SWITCHER_HOME="${CLAUDE_SWITCHER_HOME:-$HOME/Documents/claude-agents/Claude-code-agents/model-switch}"
export CLAUDE_SWITCHER_ENV="${CLAUDE_SWITCHER_ENV:-$CLAUDE_SWITCHER_HOME/.env.local}"

_cc_load_env() {
  if [ -f "$CLAUDE_SWITCHER_ENV" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$CLAUDE_SWITCHER_ENV"
    set +a
  fi

  : "${KIMI_MODEL:=moonshotai/kimi-k2.5}"
  : "${KIMI_ALIAS_MODEL:=claude-kimi-k2-5}"
  : "${KIMI_MAX_TOKENS:=8192}"
  : "${KIMI_DISABLE_THINKING:=1}"
  : "${KIMI_SMALLTALK_FAST:=0}"
  : "${KIMI_SMALLTALK_MAX_TOKENS:=256}"

  : "${NVIDIA_PROXY_HOST:=127.0.0.1}"
  : "${NVIDIA_PROXY_PORT:=3002}"
  : "${NVIDIA_PROXY_LOG:=/tmp/nvidia-proxy.log}"
  : "${NVIDIA_PROXY_CONFIG:=$HOME/.claude-nvidia-proxy/config.json}"

  : "${MODEL_ROUTER_HOST:=127.0.0.1}"
  : "${MODEL_ROUTER_PORT:=3001}"
  : "${MODEL_ROUTER_LOG:=/tmp/claude-model-router.log}"
  : "${TOPIC_DETECT_MODEL:=claude-haiku-4-5-20251001}"

  if [ -z "${NVIDIA_PROXY_BIN-}" ]; then
    NVIDIA_PROXY_BIN="$(command -v claude-nvidia-proxy 2>/dev/null || true)"
  fi
  if [ -z "${MODEL_ROUTER_BIN-}" ]; then
    MODEL_ROUTER_BIN="$(command -v claude-model-router 2>/dev/null || true)"
    if [ -z "$MODEL_ROUTER_BIN" ] && [ -x "$HOME/bin/claude-model-router" ]; then
      MODEL_ROUTER_BIN="$HOME/bin/claude-model-router"
    fi
  fi
}

_cc_clear_legacy_env() {
  unset ANTHROPIC_BASE_URL
  unset ANTHROPIC_AUTH_TOKEN
  unset ANTHROPIC_MODEL
  unset ANTHROPIC_DEFAULT_SONNET_MODEL
  unset ANTHROPIC_DEFAULT_HAIKU_MODEL
  unset ANTHROPIC_DEFAULT_OPUS_MODEL
}

_cc_spawn_daemon() {
  local log_file="$1"
  shift
  nohup "$@" > "$log_file" 2>&1 < /dev/null &
  disown >/dev/null 2>&1 || true
}

_cc_is_kimi_model() {
  case "$1" in
    "$KIMI_MODEL"|"$KIMI_ALIAS_MODEL"|moonshotai/kimi-*|*kimi*|kimi|k2.5)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

_cc_normalize_model() {
  case "$1" in
    kimi|k2.5|moonshot|moonshotai/kimi-k2.5)
      printf '%s\n' "$KIMI_ALIAS_MODEL"
      ;;
    opus|sonnet|haiku)
      printf '%s\n' "$1"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

_cc_extract_model_arg() {
  local prev=""
  local arg
  for arg in "$@"; do
    if [ "$prev" = "--model" ] || [ "$prev" = "-m" ]; then
      printf '%s\n' "$arg"
      return 0
    fi
    case "$arg" in
      --model=*)
        printf '%s\n' "${arg#--model=}"
        return 0
        ;;
      -m=*)
        printf '%s\n' "${arg#-m=}"
        return 0
        ;;
    esac
    prev="$arg"
  done
  return 1
}

_cc_read_selected_model() {
  local model
  local file
  for file in "$HOME/.claude/settings.local.json" "$HOME/.claude/settings.json"; do
    if [ -f "$file" ]; then
      model="$(jq -r '.model // empty' "$file" 2>/dev/null | head -n 1)"
      if [ -n "$model" ]; then
        printf '%s\n' "$model"
        return 0
      fi
    fi
  done
  return 0
}

_cc_write_selected_model() {
  local model="$1"
  local file="$HOME/.claude/settings.json"
  local tmp

  mkdir -p "$HOME/.claude"
  tmp="$(mktemp)"
  if [ -f "$file" ]; then
    jq --arg model "$model" '.model = $model' "$file" > "$tmp"
  else
    jq -n --arg model "$model" '{model: $model}' > "$tmp"
  fi
  mv "$tmp" "$file"
  chmod 600 "$file" 2>/dev/null || true
}

_cc_ensure_router_bin() {
  if [ -n "${MODEL_ROUTER_BIN-}" ] && [ -x "$MODEL_ROUTER_BIN" ]; then
    return 0
  fi

  if [ -x "$CLAUDE_SWITCHER_HOME/build-router.sh" ]; then
    "$CLAUDE_SWITCHER_HOME/build-router.sh" >/dev/null
    MODEL_ROUTER_BIN="${MODEL_ROUTER_BIN:-$HOME/bin/claude-model-router}"
  fi

  if [ -z "${MODEL_ROUTER_BIN-}" ] || [ ! -x "$MODEL_ROUTER_BIN" ]; then
    echo "claude-model-router binary not found. Run: $CLAUDE_SWITCHER_HOME/build-router.sh"
    return 1
  fi
}

_cc_start_nvidia_proxy() {
  _cc_load_env

  if [ -z "${NVIDIA_API_KEY-}" ]; then
    echo "NVIDIA_API_KEY missing in $CLAUDE_SWITCHER_ENV"
    return 1
  fi
  if [ -z "${NVIDIA_PROXY_BIN-}" ]; then
    echo "claude-nvidia-proxy binary not found."
    return 1
  fi

  "$CLAUDE_SWITCHER_HOME/generate-proxy-config.sh" >/dev/null

  if lsof -nP -iTCP:"$NVIDIA_PROXY_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    return 0
  fi

  _cc_spawn_daemon "$NVIDIA_PROXY_LOG" \
    env \
    CONFIG_PATH="$NVIDIA_PROXY_CONFIG" \
    ADDR=":${NVIDIA_PROXY_PORT}" \
    LOG_BODY_MAX_CHARS=0 \
    LOG_STREAM_TEXT_PREVIEW_CHARS=0 \
    "$NVIDIA_PROXY_BIN"
  sleep 2

  if ! lsof -nP -iTCP:"$NVIDIA_PROXY_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Failed to start NVIDIA proxy on $NVIDIA_PROXY_PORT"
    tail -n 20 "$NVIDIA_PROXY_LOG" 2>/dev/null || true
    return 1
  fi
}

_cc_start_router() {
  _cc_load_env
  _cc_ensure_router_bin || return 1

  if lsof -nP -iTCP:"$MODEL_ROUTER_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    return 0
  fi

  _cc_spawn_daemon "$MODEL_ROUTER_LOG" \
    env \
    MODEL_ROUTER_ADDR=":${MODEL_ROUTER_PORT}" \
    NVIDIA_PROXY_URL="http://${NVIDIA_PROXY_HOST}:${NVIDIA_PROXY_PORT}" \
    KIMI_MODEL="$KIMI_MODEL" \
    KIMI_ALIAS_MODEL="$KIMI_ALIAS_MODEL" \
    KIMI_MAX_TOKENS="$KIMI_MAX_TOKENS" \
    KIMI_DISABLE_THINKING="$KIMI_DISABLE_THINKING" \
    KIMI_SMALLTALK_FAST="$KIMI_SMALLTALK_FAST" \
    KIMI_SMALLTALK_MAX_TOKENS="$KIMI_SMALLTALK_MAX_TOKENS" \
    TOPIC_DETECT_MODEL="$TOPIC_DETECT_MODEL" \
    "$MODEL_ROUTER_BIN"
  sleep 2

  if ! lsof -nP -iTCP:"$MODEL_ROUTER_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Failed to start model router on $MODEL_ROUTER_PORT"
    tail -n 20 "$MODEL_ROUTER_LOG" 2>/dev/null || true
    return 1
  fi
}

_cc_start_stack() {
  _cc_start_nvidia_proxy || return 1
  _cc_start_router || return 1
}

_cc_router_base_url() {
  printf '%s\n' "http://${MODEL_ROUTER_HOST}:${MODEL_ROUTER_PORT}"
}

cc-sync-model() {
  _cc_load_env
  _cc_start_stack || return 1
}

cc-model() {
  _cc_load_env

  if [ $# -lt 1 ]; then
    echo "Usage: cc-model <kimi|opus|sonnet|haiku|MODEL_ID>"
    return 1
  fi

  local model
  model="$(_cc_normalize_model "$1")"

  _cc_start_stack || return 1
  _cc_write_selected_model "$model"

  if _cc_is_kimi_model "$model"; then
    echo "Switched to Kimi model: $model"
  else
    echo "Switched to Claude model: $model"
  fi
}

which-model() {
  _cc_load_env
  local selected
  selected="$(_cc_read_selected_model)"
  selected="${selected:-sonnet}"

  if _cc_is_kimi_model "$selected"; then
    echo "Active: Kimi via model-router ($selected)"
  else
    echo "Active: Claude via model-router ($selected)"
  fi
}

cc-up() {
  _cc_load_env
  _cc_start_stack || return 1
  echo "Stack ready: router ${MODEL_ROUTER_HOST}:${MODEL_ROUTER_PORT}, nvidia ${NVIDIA_PROXY_HOST}:${NVIDIA_PROXY_PORT}"
}

cc-status() {
  _cc_load_env
  echo "router:"
  lsof -nP -iTCP:"$MODEL_ROUTER_PORT" -sTCP:LISTEN 2>/dev/null || echo "not running"
  echo "nvidia proxy:"
  lsof -nP -iTCP:"$NVIDIA_PROXY_PORT" -sTCP:LISTEN 2>/dev/null || echo "not running"
}

cc-down() {
  pkill -f claude-model-router 2>/dev/null || true
  pkill -f claude-nvidia-proxy 2>/dev/null || true
  echo "Stopped local router + nvidia proxy"
}

kimi_model() {
  cc-model kimi
}

kimi_logs() {
  _cc_load_env
  touch "$NVIDIA_PROXY_LOG" 2>/dev/null || true
  echo "Tailing NVIDIA proxy log: $NVIDIA_PROXY_LOG"
  echo "Press Ctrl+C to stop log view."
  tail -n 80 -f "$NVIDIA_PROXY_LOG"
}

kimi() {
  _cc_load_env
  _cc_start_stack || return 1
  _cc_write_selected_model "$KIMI_ALIAS_MODEL"
  echo "Kimi selected: $KIMI_ALIAS_MODEL"

  if [ "${1-}" = "--no-follow" ]; then
    echo "Stack ready. Use 'kimi_logs' (or alias 'kimi-logs') to view NVIDIA proxy logs."
    return 0
  fi

  kimi_logs
}

claude-sub() {
  if [ $# -ge 1 ]; then
    cc-model "$1"
  else
    cc-model sonnet
  fi
}

claude() {
  _cc_load_env
  _cc_clear_legacy_env
  _cc_start_stack || return 1

  local explicit_model
  explicit_model="$(_cc_extract_model_arg "$@" || true)"
  if [ -n "$explicit_model" ]; then
    explicit_model="$(_cc_normalize_model "$explicit_model")"
    _cc_write_selected_model "$explicit_model" >/dev/null 2>&1 || true
  fi

  env -u ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL="$(_cc_router_base_url)" command claude "$@"
}

_cc_clear_legacy_env

alias kimi-logs='kimi_logs'
alias kimi-model='kimi_model'
