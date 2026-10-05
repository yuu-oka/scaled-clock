#!/usr/bin/env bash
# ScaledClock のロジック単体テストをヘッドレスで実行する。
# 使い方: tests/run_tests.sh
set -euo pipefail
GODOT="${GODOT:-$HOME/apps/godot/Godot_v4.7.1-stable_linux.x86_64}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_scaled_clock.gd
