#!/usr/bin/env bash
# Headless test runner for Halloween Critter Royale.
# Godot 4.x has no SceneTree exit code for tests, so the canonical signal is the
# HCTESTS:PASS / HCTESTS:FAIL token printed by the test scenes:
#   res://scenes/test/test_all.tscn        (core + rules + input spam suites)
#   res://scenes/test/test_grey_match.tscn (real scene graph, bot-vs-bot)
#   res://scenes/test/test_keyboard.tscn   (keyboard-only playthrough + UI focus)
# The runner requires one PASS token per scene.
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
  echo "run_tests: Godot binary not found (set GODOT_BIN)" >&2
  exit 3
fi

SCENES="res://scenes/test/test_all.tscn res://scenes/test/test_grey_match.tscn res://scenes/test/test_keyboard.tscn"
EXPECTED_TOKENS="${EXPECTED_TOKENS:-3}"
QUIT_AFTER="${QUIT_AFTER:-3000}"
GODOT_TIMEOUT="${GODOT_TIMEOUT:-240}"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

for SCENE in $SCENES; do
  echo "run_tests: $GODOT_BIN --headless --path \"$PROJECT_DIR\" $SCENE --quit-after $QUIT_AFTER"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$GODOT_TIMEOUT" "$GODOT_BIN" --headless --path "$PROJECT_DIR" "$SCENE" --quit-after "$QUIT_AFTER" >>"$LOG" 2>&1
  else
    "$GODOT_BIN" --headless --path "$PROJECT_DIR" "$SCENE" --quit-after "$QUIT_AFTER" >>"$LOG" 2>&1
  fi
  STATUS=$?
  if [ "$STATUS" -ne 0 ]; then
    cat "$LOG"
    echo "run_tests: engine exited with status $STATUS on $SCENE" >&2
    exit "$STATUS"
  fi
done

cat "$LOG"
if grep -q "HCTESTS:FAIL" "$LOG"; then
  exit 1
fi
PASS_COUNT="$(grep -c "HCTESTS:PASS" "$LOG" || true)"
if [ "$PASS_COUNT" -ge "$EXPECTED_TOKENS" ]; then
  exit 0
fi
echo "run_tests: expected ${EXPECTED_TOKENS} HCTESTS:PASS tokens, found ${PASS_COUNT:-0} (engine crashed or tests never ran)" >&2
exit 2
