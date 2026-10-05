# scaled-clock（倍速時計盤）

通常の12時間アナログ時計を **0.5〜3.0倍に引き伸ばした時計盤** を表示するツール。
まずWindows向け、将来iOSへ移植する前提で作っている。

---

## 1. 仕様

### 倍率 N
- 範囲 0.5〜3.0、0.5刻み（0.5 / 1.0 / 1.5 / 2.0 / 2.5 / 3.0）
- 起動時のデフォルトは 1.0
- 変更するたび `user://settings.cfg` に保存し、次回起動時に復元する

### 時刻の計算
| 概念 | 定義 |
|---|---|
| `real_sec` | 実世界の「その日の0:00からの経過秒」（システムのローカル時刻、0〜86400） |
| `scaled_sec` | 拡張時刻の経過秒 = `real_sec × N` |
| 1日の長さ | `24 × N` 時間（N=2なら48時間） |
| 拡張時刻の1時間 | 実時間 `60 / N` 分（N=2なら30分） |
| 日付の切り替わり | 実0:00で `real_sec` が0に戻るので拡張時刻も自動的に0:00に戻る |

N は 0.5 刻みなので `24N`・`12N`・`60/N` はすべて整数になり、表示が割り切れる。

### 文字盤
- 1周 = `12 × N` 時間（N=1で12時間 = 通常のアナログ時計、N=2で24時間、N=0.5で6時間）
- 数字は `1 〜 12N` の整数を等間隔に配置（12時の位置が `12N`）
- **1日 = 24N時間、文字盤1周 = 12N時間 なので、時針は倍率に関係なく必ず1日2周する**
- フォントサイズと目盛りの細かさは倍率から自動計算する（`clock_face.gd`）
  - 数字: 1つあたりに割り当てられる弧の長さから上限を決め、`plate_r * 0.155` と小さい方を採用
  - 細かい目盛り: 総数が64以下になる最大の分割数を `[10, 5, 4, 3, 2]` から選ぶ

### 針の周期
| 針 | 1周に要する時間 |
|---|---|
| 時針 | 拡張時刻で `12N` 時間 |
| 分針 | 拡張時刻で1時間 |
| 秒針 | 拡張時刻で1分 |

毎フレーム更新するので滑らかに動く。倍率を変えたときは、針が「いまの角度」から新しい角度へ
最短経路で `HAND_EASE_TIME` 秒かけて移動する（`clock_face.gd` の `_angle_offset` / `_offset_decay`）。

### 付帯表示
- 拡張時刻（`31:25:08`）＋ 1日の長さ（`/ 48h`）
- 前半 / 後半（AM/PM相当。N=1のときは通常のAM/PMと一致する。境界は常に実12:00）
- 実時刻（`15:42:34`）
- 倍率・1日の長さ・文字盤1周・拡張1時間が実時間で何分か
- 外周リング: 1周 = 1日。前半を青、後半を橙で塗り分け、経過ぶんを濃く塗る

### 画面構成（時計画面 / 設定画面）
常駐表示を邪魔しないよう、画面を2つに分けている（`Main.tscn` の `ClockScreen` /
`SettingsScreen`、`.visible` の排他切り替えのみで遷移する。シーン遷移ではない）。

| 画面 | 内容 | 入り方 |
|---|---|---|
| ClockScreen（既定） | タイトル・時計盤・デジタル表示・情報パネルのみ。倍率操作UIは出さない | 起動時、または設定画面から「← 戻る」 |
| SettingsScreen | 倍率の ±ボタン・チップ・（Windowsでは）トレイ常駐の案内文 | ClockScreenの「設定」ボタン、Escキー、トレイメニューの「設定を開く」 |

### Windowsでの常駐（タスクトレイ）
`scripts/tray_controller.gd`（`TrayController`、RefCounted）が担当。
`DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)` で機能の有無を
実行時に判定し、**対応していないプラットフォームでは何もしない**ので、
「閉じたら終了」という通常のウィンドウアプリとして動く(iOSやLinuxの一部構成でも安全)。

対応している場合（Windows）:
- 閉じるボタン（×）はアプリを終了せず、ウィンドウを隠してタスクトレイに格納する
  （`SceneTree.auto_accept_quit = false` にした上で `Window.close_requested` を捕まえている）
- タスクトレイアイコンのクリックでウィンドウの表示/非表示を切り替える
- トレイアイコンの右クリックメニュー（`NativeMenu` 経由、`FEATURE_POPUP_MENU` 判定つき）:
  「表示 / 非表示」「設定を開く」「終了」
- トレイアイコンのツールチップに現在の倍率を表示する（例: `倍速時計盤 ×2.0`）
- 完全終了は必ずトレイメニューの「終了」から（`get_tree().quit()`）。
  バックグラウンドでは `_process` が毎フレーム回り続けるので、トレイに格納していても
  拡張時刻はずれずに進み続ける

---

## 2. 構成

```
scripts/scaled_clock.gd    時刻計算のロジック（static関数のみ。描画・シーンに非依存）
scripts/settings_store.gd  倍率の保存/読み込み（user://settings.cfg）
scripts/clock_face.gd      文字盤と針の _draw() 描画（Control）
scripts/tray_controller.gd Windowsタスクトレイ常駐の制御（非対応環境では無害に何もしない）
scripts/main.gd            UIの配線（画面切り替え・デジタル表示・倍率ボタン・トレイ配線）
scenes/Main.tscn           レイアウト（ClockScreen / SettingsScreen）
tests/test_scaled_clock.gd  ScaledClock の単体テスト
tests/run_tests.sh          テスト実行スクリプト
```

**ロジックと描画/UIは分離している。** `scaled_clock.gd` は Node を継承せず（RefCounted）、
`Time` 以外のエンジン機能にも触らないので、ヘッドレスで単体テストできる。
描画側は `ScaledClock.state(real_sec, n)` が返す Dictionary だけを見ればよい。

### テスト

```bash
tests/run_tests.sh
# または
~/apps/godot/Godot_v4.7.1-stable_linux.x86_64 --headless --path . --script res://tests/test_scaled_clock.gd
```

完成条件に対応するテスト:
- `test_x2_noon_is_24h_and_one_full_turn` … N=2・実12:00 → 拡張24:00、時針がちょうど1周
- `test_x1_matches_normal_analog_clock` … N=1 で通常の12時間アナログ時計と針の角度まで一致
- `test_midnight_resets` … 実0:00で拡張時刻も0:00
- `test_hour_hand_turns_exactly_twice_per_day` … 時針は倍率によらず1日2周

---

## 3. ビルド

### Windows 向けエクスポート

```bash
~/apps/godot/Godot_v4.7.1-stable_linux.x86_64 --headless --path . --export-release "Windows" build/windows/ScaledClock.exe
```

- プリセット名は `Windows`（`export_presets.cfg`）、アーキテクチャは x86_64
- `exclude_filter` で `addons/godot_mcp/*` を除外している
- `application/modify_resources=false` にしてあるので **rcedit なしでエクスポートできる**
  （.exe にアイコンやバージョン情報を焼き込みたい場合のみ rcedit が必要）
- 出力先 `build/` は .gitignore 済み

---

## 4. iOS移植時の注意（Mac入手後にやること）

### いま守っていること（壊さないこと）
- **Windows専用API・OSコマンド・プラットフォーム固有パスを使っていない。**
  設定の保存は `user://` のみ（`settings_store.gd`）。`OS.execute()` や絶対パスは使わない。
- **時刻取得は `Time` クラスだけ**（`Time.get_unix_time_from_system()` と
  `Time.get_time_zone_from_system()`）。全プラットフォームで同じ挙動。
- **解像度非依存**: 基準ビューポート 1170x2532（iPhone縦持ち比率）、
  `stretch mode=canvas_items` / `aspect=keep`。どの解像度でもレターボックスされるだけで崩れない。
- **入力はマウス/タッチ両対応**: `Button` のみを使っているので、タッチでもクリックでも同じ。
  倍率ボタンは高さ108〜140px（基準ビューポート上）でタッチしやすい大きさ。
  キーボードの ←/→ でも倍率を変えられる（Windows向けのおまけ）。
- **画像アセットに依存しない**: 文字盤・針はすべて `_draw()` によるベクター描画。
  アイコン（`icon.svg`）とフォント以外にアセットがない。
- レンダラーは **Mobile**（`renderer/rendering_method="mobile"`）。
- `textures/vram_compression/import_etc2_astc=true` を有効済み（モバイル向けテクスチャ圧縮）。

### Mac入手後にやること
1. **macOS に Godot 4.7.1 と同じバージョンのエクスポートテンプレートを入れる。**
   バージョンがずれるとエクスポートに失敗する。
2. **Xcode をインストールし、Apple Developer アカウントでチーム設定を済ませる。**
3. **iOS エクスポートプリセットを追加する**（`export_presets.cfg` に `preset.1` として追加される）。
   - `application/bundle_identifier` を設定（例: `com.okayuu.scaledclock`）。必須。
   - `application/signature`, `application/short_version`, `application/version`
   - `application/export_method` … 開発中は `development`、配布時は `app_store` 等
   - 向きは **Portrait のみ**（`display/window/handheld/orientation=1` は設定済み。
     iOSプリセット側の `orientation` も Portrait に揃える）
4. **アイコンとランチスクリーン**: iOS はサイズ別のPNGアイコンを要求する。
   `icon.svg` から 1024x1024 ほかを書き出して割り当てる。
   （アプリ本体の描画はベクターなので追加作業は不要）
5. **セーフエリア対応を確認する。**
   いまは `MarginContainer` の固定マージン（基準ビューポートで上48/左右56/下56）で逃げている。
   ノッチ／ホームインジケータにかかる場合は `DisplayServer.get_display_safe_area()` を見て
   マージンを動的に足す。`Main.tscn` の `Margin` ノードの
   `theme_override_constants/margin_*` を実行時に上書きすればよい。
6. **`addons/godot_mcp` と MCP用autoload（`MCPRuntimeBridge` / `MCPInputBridge` /
   `MCPScreenshotBridge`）はエクスポートに含めない。** `exclude_filter` と
   `project.godot` の `[autoload]` / `[editor_plugins]` を確認すること。
7. 実機でフレームレートと時刻のずれを確認する。`_process` 毎フレームで
   `Time.get_unix_time_from_system()` を呼んでいるので、スリープ復帰後もずれない。

### 移植時に困りそうなところ
- **タイムゾーン**: `Time.get_time_zone_from_system()` の `bias` でローカル時刻を出している。
  サマータイム切り替えの瞬間に拡張時刻が最大1時間ジャンプする（毎フレーム再取得しているので
  自動的に追従はする）。日本では起きない。
- **フォント**: Noto Sans JP（約9MB）を同梱している。iOSのアプリサイズが気になる場合は
  サブセット化を検討する。
- **タスクトレイ常駐（`tray_controller.gd`）**: iOSにはタスクトレイという概念が無いので、
  `DisplayServer.has_feature(FEATURE_STATUS_INDICATOR)` が false になり自動的に無効化される。
  これ自体はコード変更不要だが、「閉じるボタンで隠す」ではなくモバイルのライフサイクル
  （バックグラウンド/フォアグラウンド遷移）に合わせた挙動になっているか実機で確認すること。
  必要なら `NOTIFICATION_APPLICATION_PAUSED` / `NOTIFICATION_APPLICATION_RESUMED` を使う
  形に差し替える。

---

## 5. Godot操作の注意（開発環境）

- Godotエディタは事前に起動しておくこと（godot-mcp接続の前提）
- WSLg特有の問題: エディタ起動時は `--display-driver x11` を付ける
  ```bash
  ~/apps/godot/Godot_v4.7.1-stable_linux.x86_64 --display-driver x11 --editor --path ~/projects/scaled-clock
  ```
- 日本語表示には Noto Sans JP が必要（`project.godot` の `gui/theme/custom_font` で設定済み）
- `addons/godot_mcp/` は .gitignore 済み。`project.godot` のMCP用autoloadと
  `[editor_plugins]` は **開発用** なので、コミット前に外すこと

## 画像確認の際のルール

スクリーンショットや生成した画像を確認・報告する際は、
必ずPNG等の汎用フォーマットで書き出し、`code <パス>` でVS Codeを自動的に開いて
ユーザーが直接見られるようにすること。ネイティブ形式のパスだけを報告して終わらない。
