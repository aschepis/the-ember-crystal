#!/bin/sh
# Refreshes Godot's import/class cache, then runs the headless test suite.
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -v "^$"
