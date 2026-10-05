extends Control

## 画面全体のまとめ役。文字盤(ClockFace)と倍率UI・デジタル表示をつなぐ。
## 時刻の計算は ScaledClock、描画は ClockFace が持ち、ここはUIの配線だけ。

const Clock := preload("res://scripts/scaled_clock.gd")
const Store := preload("res://scripts/settings_store.gd")

const COL_FIRST_HALF := Color("#4aa3ff")
const COL_SECOND_HALF := Color("#ffa63d")
const COL_CHIP_ON := Color("#4aa3ff")
const COL_CHIP_OFF := Color("#8793a8")

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

var _chip_buttons: Array[Button] = []


func _ready() -> void:
	_build_chips()
	_minus.pressed.connect(_on_step.bind(-Clock.MULTIPLIER_STEP))
	_plus.pressed.connect(_on_step.bind(Clock.MULTIPLIER_STEP))
	_apply_multiplier(Store.load_multiplier(1.0), false)


func _process(_delta: float) -> void:
	_refresh_readout()


func _unhandled_input(event: InputEvent) -> void:
	# Windowsでのキーボード操作(タッチ/マウスと併用)
	if event.is_action_pressed("ui_left"):
		_on_step(-Clock.MULTIPLIER_STEP)
	elif event.is_action_pressed("ui_right"):
		_on_step(Clock.MULTIPLIER_STEP)


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
