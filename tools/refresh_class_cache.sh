#!/usr/bin/env bash
# Regenerate .godot/global_script_class_cache.cfg (headless editor pass).
# Run this after adding or renaming any class_name script.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$HERE/.." && pwd)}"

# Godot binary resolution: $GODOT_BIN -> PATH -> common dev locations.
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="godot"
  else
    for candidate in \
      "$HOME/Desktop/Godot_v4.7.2-stable_win64_console.exe" \
      "$HOME/Desktop/Godot_v4.7.2-stable_win64.exe" \
      "$HOME/Desktop"/Godot*_win64_console.exe; do
      if [ -x "$candidate" ]; then
        GODOT_BIN="$candidate"
        break
      fi
    done
  fi
fi
if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
  echo "refresh_class_cache: Godot binary not found (set GODOT_BIN)" >&2
  exit 3
fi

"$GODOT_BIN" --headless --path "$PROJECT_DIR" --editor --quit >/dev/null 2>&1
echo "class cache refreshed"
