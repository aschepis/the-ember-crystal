#!/bin/sh
# Runs the game. First run (or after adding scripts) refreshes Godot's import cache.
#   tools/run.sh            -> opens the Debug Lab
#   tools/run.sh --title    -> opens the title screen
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi
exec "$GODOT" --path . -- "$@"
