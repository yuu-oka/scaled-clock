# 倍速時計盤 (scaled-clock)

通常の12時間アナログ時計を **0.5〜3.0倍に引き伸ばした時計盤** を表示するツール。

| 倍率 | 1日の長さ | 文字盤1周 | 文字盤の数字 | 拡張1時間 |
|---|---|---|---|---|
| ×0.5 | 12時間 | 6時間 | 1〜6 | 実120分 |
| ×1.0 | 24時間 | 12時間 | 1〜12（通常の時計） | 実60分 |
| ×1.5 | 36時間 | 18時間 | 1〜18 | 実40分 |
| ×2.0 | 48時間 | 24時間 | 1〜24 | 実30分 |
| ×2.5 | 60時間 | 30時間 | 1〜30 | 実24分 |
| ×3.0 | 72時間 | 36時間 | 1〜36 | 実20分 |

実世界の「その日の0:00からの経過秒」を N 倍した時刻を表示する。
実0:00で拡張時刻も0:00に戻るので、1日の区切りは実世界とずれない。

## 動かす

Godot 4.7.1 でプロジェクトを開いて実行する。

```bash
# テスト
tests/run_tests.sh

# Windows向けビルド
godot --headless --path . --export-release "Windows" build/windows/ScaledClock.exe
```

## 構成

- `scripts/scaled_clock.gd` — 時刻計算（描画・シーンに非依存／単体テスト対象）
- `scripts/clock_face.gd` — 文字盤と針の `_draw()` ベクター描画
- `scripts/main.gd` — UI配線
- `scripts/settings_store.gd` — 倍率の永続化（`user://settings.cfg`）

仕様・iOS移植時の注意は [CLAUDE.md](CLAUDE.md) を参照。
