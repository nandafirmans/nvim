#!/usr/bin/env bash
set -euo pipefail

NVIM_BIN="${NVIM_BIN:-$(command -v nvim || true)}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [[ -z "$NVIM_BIN" ]]; then
  echo "nvim: binary not found; skipped"
  exit 0
fi

count=0
for sock in "$RUNTIME_DIR"/nvim.*; do
  [[ -S "$sock" ]] || continue
  if "$NVIM_BIN" --server "$sock" --remote-expr 'execute("lua package.loaded[\"core.ui\"] = nil; require(\"core.ui\").setup(); require(\"core.ui\").reload_walltheme()")' >/dev/null 2>&1; then
    count=$((count + 1))
  fi
done

echo "nvim: reloaded walltheme in $count server(s)"
