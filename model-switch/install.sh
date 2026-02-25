#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWITCHER="$REPO_ROOT/model-switch/switcher.zsh"
ENV_EXAMPLE="$REPO_ROOT/model-switch/.env.example"
ENV_LOCAL="$REPO_ROOT/model-switch/.env.local"
BUILD_ROUTER="$REPO_ROOT/model-switch/build-router.sh"

if [ ! -f "$ENV_LOCAL" ]; then
  cp "$ENV_EXAMPLE" "$ENV_LOCAL"
  chmod 600 "$ENV_LOCAL"
  echo "Created $ENV_LOCAL"
  echo "Edit it and set NVIDIA_API_KEY, then rerun this script."
fi

if [ -x "$BUILD_ROUTER" ]; then
  "$BUILD_ROUTER"
fi

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  line="[ -f \"$SWITCHER\" ] && source \"$SWITCHER\""
  if ! rg -F "$SWITCHER" "$rc" >/dev/null 2>&1; then
    printf '\n# Claude model switcher\n%s\n' "$line" >> "$rc"
    echo "Updated $rc"
  fi
done

echo "Done. Run: source ~/.zshrc"
