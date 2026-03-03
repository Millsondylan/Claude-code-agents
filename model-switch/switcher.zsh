# shellcheck shell=bash
# Claude Code Model Switcher - 3 providers: Claude (OAuth), Kimi K2.5, GLM-5

export CLAUDE_SWITCHER_HOME="${CLAUDE_SWITCHER_HOME:-$HOME/Documents/claude-agents/Claude-code-agents/model-switch}"
export CLAUDE_SWITCHER_ENV="${CLAUDE_SWITCHER_ENV:-$CLAUDE_SWITCHER_HOME/.env.local}"

_cc_load_env() {
  if [ -f "$CLAUDE_SWITCHER_ENV" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$CLAUDE_SWITCHER_ENV"
    set +a
  fi

  : "${KIMI_MODEL:=kimi-k2.5}"
  : "${GLM_MODEL:=glm-5}"
  : "${KIMI_MAX_TOKENS:=16384}"
  : "${GLM_MAX_TOKENS:=16384}"

  : "${LITELLM_BASE_URL:=http://127.0.0.1:4000}"
  : "${LITELLM_API_KEY:=sk-litellm-local-proxy-key}"

  : "${MODEL_ROUTER_HOST:=127.0.0.1}"
  : "${MODEL_ROUTER_PORT:=3001}"
  : "${MODEL_ROUTER_LOG:=/tmp/claude-model-router.log}"

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
}

_cc_spawn_daemon() {
  local log_file="$1"
  shift
  nohup "$@" > "$log_file" 2>&1 < /dev/null &
  disown >/dev/null 2>&1 || true
}

_cc_detect_provider() {
  case "$1" in
    "$KIMI_MODEL"|*kimi*|moonshot|k2.5)
      printf 'kimi\n'
      ;;
    "$GLM_MODEL"|*glm*)
      printf 'glm\n'
      ;;
    *)
      printf 'claude\n'
      ;;
  esac
}

_cc_normalize_model() {
  case "$1" in
    kimi|k2.5|moonshot)
      printf '%s\n' "$KIMI_MODEL"
      ;;
    glm|glm5|glm-5)
      printf '%s\n' "$GLM_MODEL"
      ;;
    opus|sonnet|haiku)
      printf '%s\n' "$1"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
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

_cc_start_litellm() {
  # LiteLLM should be running via launchd (com.litellm.proxy)
  if lsof -nP -iTCP:4000 -sTCP:LISTEN >/dev/null 2>&1; then
    return 0
  fi
  echo "LiteLLM proxy not running on port 4000. Start it with: launchctl load ~/Library/LaunchAgents/com.litellm.proxy.plist"
  return 1
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
    LITELLM_BASE_URL="$LITELLM_BASE_URL" \
    LITELLM_API_KEY="$LITELLM_API_KEY" \
    KIMI_MODEL="$KIMI_MODEL" \
    KIMI_MAX_TOKENS="$KIMI_MAX_TOKENS" \
    GLM_MODEL="$GLM_MODEL" \
    GLM_MAX_TOKENS="$GLM_MAX_TOKENS" \
    "$MODEL_ROUTER_BIN"
  sleep 1

  if ! lsof -nP -iTCP:"$MODEL_ROUTER_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Failed to start model router on $MODEL_ROUTER_PORT"
    tail -n 20 "$MODEL_ROUTER_LOG" 2>/dev/null || true
    return 1
  fi
}

_cc_start_stack() {
  _cc_start_litellm || return 1
  _cc_start_router || return 1
}

_cc_router_base_url() {
  printf '%s\n' "http://${MODEL_ROUTER_HOST}:${MODEL_ROUTER_PORT}"
}

# --- User-facing commands ---

cc-model() {
  _cc_load_env

  if [ $# -lt 1 ]; then
    echo "Usage: cc-model <kimi|glm|opus|sonnet|haiku|MODEL_ID>"
    return 1
  fi

  local model provider
  model="$(_cc_normalize_model "$1")"
  provider="$(_cc_detect_provider "$model")"

  _cc_start_stack || return 1

  echo "Switched to $provider model: $model"
}

which-model() {
  _cc_load_env
  echo "Available providers:"
  echo "  claude (opus 4.6) - OAuth pass-through"
  echo "  kimi  ($KIMI_MODEL) - via LiteLLM"
  echo "  glm   ($GLM_MODEL)  - via LiteLLM"
  echo ""
  echo "Router: http://${MODEL_ROUTER_HOST}:${MODEL_ROUTER_PORT}"
}

cc-up() {
  _cc_load_env
  _cc_start_stack || return 1
  echo "Stack ready:"
  echo "  router:  ${MODEL_ROUTER_HOST}:${MODEL_ROUTER_PORT}"
  echo "  litellm: 127.0.0.1:4000"
  echo "  providers: claude (direct), kimi (litellm), glm (litellm)"
}

cc-status() {
  _cc_load_env
  echo "Go router (port $MODEL_ROUTER_PORT):"
  lsof -nP -iTCP:"$MODEL_ROUTER_PORT" -sTCP:LISTEN 2>/dev/null || echo "  not running"
  echo "LiteLLM proxy (port 4000):"
  lsof -nP -iTCP:4000 -sTCP:LISTEN 2>/dev/null || echo "  not running"
}

cc-down() {
  pkill -f claude-model-router 2>/dev/null || true
  echo "Stopped model router"
}

cc-logs() {
  _cc_load_env
  echo "Tailing router log: $MODEL_ROUTER_LOG"
  tail -n 80 -f "$MODEL_ROUTER_LOG"
}

claude() {
  _cc_load_env
  _cc_clear_legacy_env
  _cc_start_stack || return 1

  # Route through Go router, remap aliases to external models
  env -u ANTHROPIC_AUTH_TOKEN \
    ANTHROPIC_BASE_URL="$(_cc_router_base_url)" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$KIMI_MODEL" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$GLM_MODEL" \
    command claude "$@"
}

_cc_clear_legacy_env
