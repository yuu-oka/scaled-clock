extends Control
class_name ClockFace

## 文字盤と針を _draw() でベクター描画する。画像アセットは一切使わない。
## 時刻の計算は ScaledClock に任せ、ここは見た目だけを担当する。

const Clock := preload("res://scripts/scaled_clock.gd")
const FONT := preload("res://theme/fonts/NotoSansJP-VariableFont_wght.ttf")

# ダークテーマの配色
const COL_PLATE := Color("#171a21")
const COL_PLATE_EDGE := Color("#2c3344")
const COL_TICK_MAJOR := Color("#c8d2e4")
const COL_TICK_MINOR := Color("#4d566b")
const COL_NUMBER := Color("#e6ecf7")
const COL_HOUR_HAND := Color("#f2f5fb")
const COL_MINUTE_HAND := Color("#aebbd2")
const COL_SECOND_HAND := Color("#ff5d5d")
const COL_RING_TRACK := Color("#1d222d")
const COL_FIRST_HALF := Color("#4aa3ff")
const COL_SECOND_HALF := Color("#ffa63d")
# リングは「時計の添え物」なので、ラベル用の原色より彩度・明度を落とした色を使う
const COL_RING_FIRST := Color("#4a7cad")
const COL_RING_SECOND := Color("#ad7d49")

## 倍率が変わったとき針が滑らかに移動する時間(秒)
const HAND_EASE_TIME := 0.55
## 文字盤の数字が密集しすぎないよう、目盛りの総数はこの値以下に抑える
const MAX_MINOR_TICKS := 64
## 文字盤の数字のウェイト。小さいサイズでも潰れないよう少し太らせる。
const NUMBER_WEIGHT := 600.0

var _multiplier := 1.0
var _state: Dictionary = {}
## 倍率変更時の「見た目の角度 - 本来の角度」。0へ減衰させることで針が自然に動く。
var _angle_offset := [0.0, 0.0, 0.0]
var _offset_decay := 0.0
## 文字盤の数字用(同じttfをウェイト違いで使うだけ。フォントは追加しない)
var _number_font: FontVariation


func _ready() -> void:
	_number_font = FontVariation.new()
	_number_font.base_font = FONT
	_number_font.variation_opentype = {"wght": NUMBER_WEIGHT}
	_state = Clock.state(Clock.real_seconds_now(), _multiplier)


func _process(delta: float) -> void:
	if _offset_decay > 0.0:
		_offset_decay = maxf(_offset_decay - delta / HAND_EASE_TIME, 0.0)
	_state = Clock.state(Clock.real_seconds_now(), _multiplier)
	queue_redraw()


func get_multiplier() -> float:
	return _multiplier


## 現在の表示状態(デジタル表示などに使う)。
func get_state() -> Dictionary:
	return _state


## 倍率を変更する。針は現在位置から最短経路で滑らかに移動する。
func set_multiplier(value: float) -> void:
	var next: float = Clock.clamp_multiplier(value)
	if is_equal_approx(next, _multiplier):
		return

	var real_sec: float = Clock.real_seconds_now()
	var before: Dictionary = Clock.state(real_sec, _multiplier)
	var after: Dictionary = Clock.state(real_sec, next)
	var keys := ["hour_angle", "minute_angle", "second_angle"]
	var weight := _offset_weight()
	for i in keys.size():
		var shown: float = before[keys[i]] + _angle_offset[i] * weight
		# 最短経路で回るように [-PI, PI] に畳む
		_angle_offset[i] = wrapf(shown - after[keys[i]], -PI, PI)

	_offset_decay = 1.0
	_multiplier = next
	_state = after
	queue_redraw()


func _offset_weight() -> float:
	return smoothstep(0.0, 1.0, _offset_decay)


func _eased_angle(key: String, index: int) -> float:
	var base: float = _state.get(key, 0.0)
	if _offset_decay <= 0.0:
		return base
	return base + _angle_offset[index] * _offset_weight()


## 12時方向を0、時計回りを正とした単位ベクトル(画面座標はy下向き)。
static func _dir(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))


## 時計の角度(12時=0, 時計回り)を draw_arc 用の角度(3時=0)へ変換する。
static func _arc_angle(angle: float) -> float:
	return angle - PI * 0.5


## 目盛りを何分割するか。倍率が上がっても密集しすぎないよう自動で粗くする。
static func _minor_subdivisions(number_count: int) -> int:
	for sub in [10, 5, 4, 3, 2]:
		if number_count * sub <= MAX_MINOR_TICKS:
			return sub
	return 1


func _draw() -> void:
	if _state.is_empty():
		return

	var center := size * 0.5
	# 常に正方形に収めるので縦長/横長どちらのウィンドウでも崩れない
	var radius := minf(size.x, size.y) * 0.5
	if radius <= 4.0:
		return

	_draw_day_ring(center, radius)

	var plate_r := radius * 0.875
	draw_circle(center, plate_r, COL_PLATE)
	draw_arc(center, plate_r, 0.0, TAU, 128, COL_PLATE_EDGE, maxf(radius * 0.008, 1.0), true)

	_draw_ticks(center, plate_r)
	_draw_numbers(center, plate_r)
	_draw_hands(center, plate_r)


## 文字盤の外周リング。1周=1日(24N時間)で、前半を青・後半を橙に塗り分ける。
func _draw_day_ring(center: Vector2, radius: float) -> void:
	# 文字盤(0.875)との間にわずかな余白を残しつつ、細く控えめに描く
	var ring_r := radius * 0.957
	var width := radius * 0.042
	var progress: float = _state["day_progress"]

	draw_arc(center, ring_r, 0.0, TAU, 160, COL_RING_TRACK, width, true)
	# 右半分が前半、左半分が後半(12時方向から時計回り)
	draw_arc(
		center, ring_r, _arc_angle(0.0), _arc_angle(PI), 80,
		Color(COL_RING_FIRST, 0.13), width, true
	)
	draw_arc(
		center, ring_r, _arc_angle(PI), _arc_angle(TAU), 80,
		Color(COL_RING_SECOND, 0.13), width, true
	)

	# 経過ぶんを濃く塗る(前半は青、後半は前半ぶんを青、残りを橙)
	var half_angle := PI
	var elapsed := TAU * progress
	if elapsed > 0.0005:
		var first_end := minf(elapsed, half_angle)
		draw_arc(
			center, ring_r, _arc_angle(0.0), _arc_angle(first_end), 80,
			COL_RING_FIRST, width, true
		)
		if elapsed > half_angle:
			draw_arc(
				center, ring_r, _arc_angle(half_angle), _arc_angle(elapsed), 80,
				COL_RING_SECOND, width, true
			)

	# 現在位置のマーカー
	var marker_pos := center + _dir(elapsed) * ring_r
	var marker_col: Color = COL_RING_SECOND if _state["is_second_half"] else COL_RING_FIRST
	draw_circle(marker_pos, width * 0.80, COL_PLATE)
	draw_circle(marker_pos, width * 0.62, Color("#dde4f1"))
	draw_circle(marker_pos, width * 0.36, marker_col)


func _draw_ticks(center: Vector2, plate_r: float) -> void:
	var count: int = _state["dial_number_count"]
	var sub := _minor_subdivisions(count)

	# 細かい目盛り
	if sub > 1:
		var minor_total := count * sub
		var w := maxf(plate_r * 0.006, 1.0)
		for i in minor_total:
			if i % sub == 0:
				continue
			var a := TAU * float(i) / float(minor_total)
			var d := _dir(a)
			draw_line(center + d * (plate_r * 0.93), center + d * (plate_r * 0.965), COL_TICK_MINOR, w, true)

	# 時間ごとの太い目盛り
	var major_w := maxf(plate_r * 0.014, 1.5)
	for i in count:
		var a := TAU * float(i) / float(count)
		var d := _dir(a)
		draw_line(center + d * (plate_r * 0.90), center + d * (plate_r * 0.97), COL_TICK_MAJOR, major_w, true)


func _draw_numbers(center: Vector2, plate_r: float) -> void:
	var font: Font = _number_font if _number_font != null else FONT
	var count: int = _state["dial_number_count"]
	# 目盛りのすぐ内側まで数字を出すと、1つあたりの弧が広がって大きな字を置ける
	var number_r := plate_r * 0.805
	# 数字1つに割り当てられる弧の長さ。倍率が上がるほど狭くなる。
	var slot := TAU * number_r / float(count)

	# 一番幅の広い表示(=最大の数字)を基準にフォントサイズを決める
	var widest := str(count)
	var probe := font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	# 隣との最小の隙間ぶん(18%)だけ残して、残りを文字幅に使う
	var by_slot := 100.0 * (slot * 0.82) / maxf(probe, 1.0)
	var font_size := clampf(minf(plate_r * 0.155, by_slot), 7.0, plate_r)

	for i in count:
		var label := str(count if i == 0 else i)
		var a := TAU * float(i) / float(count)
		var px := int(font_size)
		var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var target := center + _dir(a) * number_r
		# draw_string はベースライン基準なので、文字の中心を target に合わせる
		var pos := Vector2(
			target.x - text_w * 0.5,
			target.y + (font.get_ascent(px) - font.get_descent(px)) * 0.5
		)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, COL_NUMBER)


func _draw_hands(center: Vector2, plate_r: float) -> void:
	var hour_a := _eased_angle("hour_angle", 0)
	var minute_a := _eased_angle("minute_angle", 1)
	var second_a := _eased_angle("second_angle", 2)

	_draw_hand(center, hour_a, plate_r * 0.52, plate_r * 0.042, plate_r * 0.13, COL_HOUR_HAND)
	_draw_hand(center, minute_a, plate_r * 0.76, plate_r * 0.026, plate_r * 0.15, COL_MINUTE_HAND)

	# 秒針は細いので線で描く
	var d := _dir(second_a)
	var w := maxf(plate_r * 0.009, 1.0)
	draw_line(center - d * (plate_r * 0.18), center + d * (plate_r * 0.84), COL_SECOND_HAND, w, true)

	draw_circle(center, plate_r * 0.035, COL_HOUR_HAND)
	draw_circle(center, plate_r * 0.016, COL_SECOND_HAND)


func _draw_hand(
	center: Vector2, angle: float, length: float, half_width: float, tail: float, color: Color
) -> void:
	var d := _dir(angle)
	var p := Vector2(d.y, -d.x)
	var pts := PackedVector2Array([
		center + d * length,
		center + d * (length * 0.12) + p * half_width,
		center - d * tail + p * (half_width * 0.75),
		center - d * tail - p * (half_width * 0.75),
		center + d * (length * 0.12) - p * half_width,
	])
	draw_colored_polygon(pts, color)
