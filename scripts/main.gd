extends Control

## 画面全体のまとめ役。文字盤(ClockFace)と倍率UI・デジタル表示をつなぐ。
## 時刻の計算は ScaledClock、描画は ClockFace が持ち、ここはUIの配線だけ。
##
## 画面は2つ:
##   ClockScreen    … 時計盤とデジタル表示のみ(常駐表示用。倍率操作のUIは出さない)
##   SettingsScreen … 倍率を変更するための設定画面
## 歯車ボタンで行き来する。
##
## Windowsではタスクトレイに常駐できる(TrayController)。閉じるボタンは
## トレイに格納されるだけで終了しない。完全終了はトレイメニューの「終了」から。
## トレイ機能が無いプラットフォーム(Linux/X11の一部構成やiOSなど)では
## 自動的に「閉じたら終了」という通常の挙動にフォールバックする。

const Clock := preload("res://scripts/scaled_clock.gd")
const Store := preload("res://scripts/settings_store.gd")
const Tray := preload("res://scripts/tray_controller.gd")

const COL_FIRST_HALF := Color("#4aa3ff")
const COL_SECOND_HALF := Color("#ffa63d")
const COL_CHIP_ON := Color("#4aa3ff")
const COL_CHIP_OFF := Color("#8793a8")

const APP_TITLE := "倍速時計盤"

@onready var _face: ClockFace = %ClockFace
@onready var _scaled_time: Label = %ScaledTime
@onready var _day_length: Label = %DayLength
@onready var _half: Label = %HalfLabel
@onready var _real_time: Label = %RealTime
@onready var _info_day: Label = %InfoDay
@onready var _info_hour: Label = %InfoHour
@onready var _mult_value: Label = %MultValue
@onready var _minus: Button = %MinusButton
@onready var _plus: Button = %PlusButton
@onready var _chips: HBoxContainer = %Chips
@onready var _clock_screen: Control = %ClockScreen
@onready var _settings_screen: Control = %SettingsScreen
@onready var _settings_button: Button = %SettingsButton
@onready var _back_button: Button = %BackButton
@onready var _tray_hint: Label = %TrayHint
@onready var _face_wrap: Control = %FaceWrap
@onready var _face_visibility_button: Button = %FaceVisibilityButton
@onready var _face_mode_button: Button = %FaceModeButton

var _chip_buttons: Array[Button] = []
var _tray := Tray.new()


func _ready() -> void:
	_build_chips()
	_minus.pressed.connect(_on_step.bind(-Clock.MULTIPLIER_STEP))
	_plus.pressed.connect(_on_step.bind(Clock.MULTIPLIER_STEP))
	_settings_button.pressed.connect(_show_settings.bind(true))
	_back_button.pressed.connect(_show_settings.bind(false))
	_face_visibility_button.pressed.connect(_on_toggle_face_visibility)
	_face_mode_button.pressed.connect(_on_toggle_face_mode)
	_apply_multiplier(Store.load_multiplier(1.0), false)
	_apply_show_face(Store.load_show_face(true), false)
	_apply_face_mode(Store.load_face_mode(Clock.FaceMode.HALF_DAY), false)
	_show_settings(false)
	_setup_tray()


func _exit_tree() -> void:
	_tray.teardown()


func _process(_delta: float) -> void:
	_refresh_readout()


func _unhandled_input(event: InputEvent) -> void:
	# Windowsでのキーボード操作(タッチ/マウスと併用)
	if event.is_action_pressed("ui_left"):
		_on_step(-Clock.MULTIPLIER_STEP)
	elif event.is_action_pressed("ui_right"):
		_on_step(Clock.MULTIPLIER_STEP)
	elif event.is_action_pressed("ui_cancel") and _settings_screen.visible:
		_show_settings(false)


## --------------------------------------------------------------- 画面切り替え

func _show_settings(show_settings: bool) -> void:
	_clock_screen.visible = not show_settings
	_settings_screen.visible = show_settings


## ------------------------------------------------------------- タスクトレイ

## Windowsではタスクトレイアイコンを作り、閉じるボタンを「隠す」に変える。
## 対応していないプラットフォームでは何もしない(通常どおり閉じたら終了する)。
func _setup_tray() -> void:
	_tray.setup(
		preload("res://icon.svg"),
		APP_TITLE,
		_on_tray_toggle_visibility,
		_on_tray_open_settings,
		_on_tray_quit,
	)
	if not _tray.available:
		return

	if _tray_hint:
		_tray_hint.text = "ウィンドウを閉じるとタスクトレイに格納されます"
		_tray_hint.visible = true

	# OSからの「閉じる」要求ではアプリを終了させず、ウィンドウを隠すだけにする。
	var tree := get_tree()
	tree.auto_accept_quit = false
	tree.root.close_requested.connect(_on_window_close_requested)


func _on_window_close_requested() -> void:
	get_tree().root.hide()


func _on_tray_toggle_visibility() -> void:
	var window := get_tree().root
	if window.visible:
		window.hide()
	else:
		window.show()
		window.move_to_foreground()
		window.grab_focus()


func _on_tray_open_settings() -> void:
	var window := get_tree().root
	window.show()
	window.move_to_foreground()
	window.grab_focus()
	_show_settings(true)


func _on_tray_quit() -> void:
	_tray.teardown()
	get_tree().quit()


## ----------------------------------------------------------------- 倍率UI

## 0.5〜3.0 の倍率を直接選べるボタンを並べる。タッチしやすい大きさにする。
func _build_chips() -> void:
	for value in Clock.multiplier_choices():
		var button := Button.new()
		button.text = "×%.1f" % value
		button.custom_minimum_size = Vector2(0, 108)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 44)
		button.pressed.connect(_apply_multiplier.bind(value, true))
		_chips.add_child(button)
		_chip_buttons.append(button)


func _on_step(delta: float) -> void:
	_apply_multiplier(_face.get_multiplier() + delta, true)


func _apply_multiplier(value: float, persist: bool) -> void:
	var n: float = Clock.clamp_multiplier(value)
	_face.set_multiplier(n)
	_mult_value.text = "×%.1f" % n
	_minus.disabled = is_equal_approx(n, Clock.MIN_MULTIPLIER)
	_plus.disabled = is_equal_approx(n, Clock.MAX_MULTIPLIER)

	var choices := Clock.multiplier_choices()
	for i in _chip_buttons.size():
		var selected := is_equal_approx(choices[i], n)
		_chip_buttons[i].add_theme_color_override(
			"font_color", COL_CHIP_ON if selected else COL_CHIP_OFF
		)
		_chip_buttons[i].add_theme_color_override(
			"font_hover_color", COL_CHIP_ON if selected else COL_CHIP_OFF
		)

	if persist:
		Store.save_multiplier(n)
	_tray.set_tooltip("%s ×%.1f" % [APP_TITLE, n])
	_refresh_readout()


## ------------------------------------------------------------- 文字盤の表示設定

func _on_toggle_face_visibility() -> void:
	_apply_show_face(not _face_wrap.visible, true)


## 文字盤(アナログ表示)の表示/非表示を切り替える。非表示でもデジタル表示は
## 動き続ける(ClockFaceの_processは可視状態に関係なく回り続けるため)。
func _apply_show_face(show_face: bool, persist: bool) -> void:
	_face_wrap.visible = show_face
	_face_visibility_button.text = "表示中" if show_face else "非表示中"
	if persist:
		Store.save_show_face(show_face)


func _on_toggle_face_mode() -> void:
	var current := _face.get_face_mode()
	var next := (
		Clock.FaceMode.FULL_DAY if current == Clock.FaceMode.HALF_DAY
		else Clock.FaceMode.HALF_DAY
	)
	_apply_face_mode(next, true)


## 文字盤の表示方式を切り替える。
## HALF_DAY: 文字盤1周=12N時間、1日2周(AM/PM表示)。
## FULL_DAY: 文字盤1周=24N時間、1日ちょうど1周。
func _apply_face_mode(mode: int, persist: bool) -> void:
	_face.set_face_mode(mode)
	_face_mode_button.text = "AM/PM表示" if mode == Clock.FaceMode.HALF_DAY else "1日1周表示"
	if persist:
		Store.save_face_mode(mode)
	_refresh_readout()


func _refresh_readout() -> void:
	var state := _face.get_state()
	if state.is_empty():
		return
	_scaled_time.text = state["scaled_text"]
	_day_length.text = "/ %dh" % int(state["day_hours"])
	_half.text = state["half_label"]
	_half.add_theme_color_override(
		"font_color", COL_SECOND_HALF if state["is_second_half"] else COL_FIRST_HALF
	)
	_real_time.text = state["real_text"]
	_info_day.text = "倍率 ×%.1f ／ 1日 = %d時間 ／ 文字盤1周 = %d時間" % [
		state["multiplier"], int(state["day_hours"]), int(state["dial_hours"])
	]
	_info_hour.text = "拡張時刻の1時間 = 実時間 %d分" % int(
		round(state["real_minutes_per_scaled_hour"])
	)
