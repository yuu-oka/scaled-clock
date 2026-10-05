extends SceneTree

## ScaledClock の単体テスト。描画やシーンに依存しない。
##
## 実行:
##   godot --headless --path <project> --script res://tests/test_scaled_clock.gd

const Clock := preload("res://scripts/scaled_clock.gd")

const H := 3600.0
const EPS := 0.000001

var _passed := 0
var _failed := 0


func _initialize() -> void:
	test_clamp_multiplier()
	test_multiplier_choices()
	test_day_and_dial_sizes()
	test_real_minutes_per_scaled_hour()
	test_x2_noon_is_24h_and_one_full_turn()
	test_x1_matches_normal_analog_clock()
	test_x05_half_speed()
	test_midnight_resets()
	test_hour_hand_turns_exactly_twice_per_day()
	test_minute_and_second_hand_periods()
	test_halves()
	test_scaled_roundtrip()
	test_state_never_exceeds_day_length()

	print("")
	if _failed == 0:
		print("OK: %d assertions passed" % _passed)
		quit(0)
	else:
		print("FAILED: %d passed / %d failed" % [_passed, _failed])
		quit(1)


# ---------------------------------------------------------------- assertions

func _ok(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL  %s" % label)


func _eq_f(actual: float, expected: float, label: String, eps := EPS) -> void:
	_ok(absf(actual - expected) <= eps, "%s (expected %f, got %f)" % [label, expected, actual])


func _eq_i(actual: int, expected: int, label: String) -> void:
	_ok(actual == expected, "%s (expected %d, got %d)" % [label, expected, actual])


func _eq_s(actual: String, expected: String, label: String) -> void:
	_ok(actual == expected, "%s (expected '%s', got '%s')" % [label, expected, actual])


# --------------------------------------------------------------------- tests

func test_clamp_multiplier() -> void:
	print("clamp_multiplier")
	_eq_f(Clock.clamp_multiplier(1.0), 1.0, "1.0 はそのまま")
	_eq_f(Clock.clamp_multiplier(1.2), 1.0, "1.2 は 1.0 に丸める")
	_eq_f(Clock.clamp_multiplier(1.3), 1.5, "1.3 は 1.5 に丸める")
	_eq_f(Clock.clamp_multiplier(0.0), 0.5, "下限は 0.5")
	_eq_f(Clock.clamp_multiplier(-5.0), 0.5, "負の値も 0.5")
	_eq_f(Clock.clamp_multiplier(9.9), 3.0, "上限は 3.0")


func test_multiplier_choices() -> void:
	print("multiplier_choices")
	var choices := Clock.multiplier_choices()
	_eq_i(choices.size(), 6, "選択肢は6個")
	var expected := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
	for i in expected.size():
		_eq_f(choices[i], expected[i], "choices[%d]" % i)


func test_day_and_dial_sizes() -> void:
	print("day_hours / dial_hours / dial_number_count")
	var cases := {
		0.5: [12, 6, 6],
		1.0: [24, 12, 12],
		1.5: [36, 18, 18],
		2.0: [48, 24, 24],
		2.5: [60, 30, 30],
		3.0: [72, 36, 36],
	}
	for n in cases:
		var want: Array = cases[n]
		_eq_i(int(Clock.day_hours(n)), want[0], "N=%.1f の1日の時間数" % n)
		_eq_i(int(Clock.dial_hours(n)), want[1], "N=%.1f の文字盤1周" % n)
		_eq_i(Clock.dial_number_count(n), want[2], "N=%.1f の数字の個数" % n)


func test_real_minutes_per_scaled_hour() -> void:
	print("real_minutes_per_scaled_hour")
	_eq_f(Clock.real_minutes_per_scaled_hour(0.5), 120.0, "N=0.5 → 120分")
	_eq_f(Clock.real_minutes_per_scaled_hour(1.0), 60.0, "N=1.0 → 60分")
	_eq_f(Clock.real_minutes_per_scaled_hour(1.5), 40.0, "N=1.5 → 40分")
	_eq_f(Clock.real_minutes_per_scaled_hour(2.0), 30.0, "N=2.0 → 30分")
	_eq_f(Clock.real_minutes_per_scaled_hour(2.5), 24.0, "N=2.5 → 24分")
	_eq_f(Clock.real_minutes_per_scaled_hour(3.0), 20.0, "N=3.0 → 20分")


## 完成条件: N=2 で実時刻12:00に拡張時刻が24:00、時針はちょうど1周。
func test_x2_noon_is_24h_and_one_full_turn() -> void:
	print("N=2 / 実12:00 → 拡張24:00 かつ時針1周")
	var s := Clock.state(12.0 * H, 2.0)
	_eq_s(s["scaled_text"], "24:00:00", "拡張時刻の表示")
	_eq_i(s["scaled_hour"], 24, "拡張の時")
	_eq_s(s["real_text"], "12:00:00", "実時刻の表示")
	_eq_i(int(s["day_hours"]), 48, "1日 = 48時間")
	# 時針の周期は 24時間(拡張) = 86400拡張秒。scaled_sec も 86400 なのでちょうど1周 → 角度0
	_eq_f(Clock.hour_hand_period(2.0), 86400.0, "時針の周期(拡張秒)")
	_eq_f(s["scaled_sec"], 86400.0, "拡張経過秒")
	_eq_f(s["hour_angle"], 0.0, "時針は1周してちょうど12時方向", 0.0001)
	# 1周したことを「角度0かつ周期ぴったり」だけでなく、直前の値でも確かめる
	var just_before := Clock.state(12.0 * H - 1.0, 2.0)
	_ok(just_before["hour_angle"] > TAU - 0.01, "直前は1周手前(角度がTAU近傍)")
	_ok(s["is_second_half"], "24:00 は1日の後半のはじまり")


## 完成条件: N=1 では通常の12時間アナログ時計と完全に同じ。
func test_x1_matches_normal_analog_clock() -> void:
	print("N=1 → 通常の12時間アナログ時計と一致")
	# 15:42:34
	var real_sec := 15.0 * H + 42.0 * 60.0 + 34.0
	var s := Clock.state(real_sec, 1.0)
	_eq_s(s["scaled_text"], "15:42:34", "拡張時刻 = 実時刻")
	_eq_s(s["real_text"], "15:42:34", "実時刻")
	_eq_i(s["dial_number_count"], 12, "文字盤は1〜12")
	_eq_f(s["scaled_sec"], real_sec, "拡張秒 = 実秒")

	# 通常時計の針の角度(12時=0, 時計回り)
	var h12 := fmod(15.0, 12.0) + 42.0 / 60.0 + 34.0 / 3600.0
	_eq_f(s["hour_angle"], TAU * h12 / 12.0, "時針は通常時計と同じ", 0.00001)
	_eq_f(s["minute_angle"], TAU * (42.0 + 34.0 / 60.0) / 60.0, "分針は通常時計と同じ", 0.00001)
	_eq_f(s["second_angle"], TAU * 34.0 / 60.0, "秒針は通常時計と同じ", 0.00001)

	# 前半/後半 は AM/PM と一致する
	_eq_s(Clock.half_label(9.0 * H, 1.0), "前半", "9時は前半(AM)")
	_eq_s(Clock.half_label(15.0 * H, 1.0), "後半", "15時は後半(PM)")
	_eq_s(Clock.half_label(0.0, 1.0), "前半", "0時は前半")
	_eq_s(Clock.half_label(12.0 * H, 1.0), "後半", "12時は後半")


func test_x05_half_speed() -> void:
	print("N=0.5 → 1日12時間 / 文字盤6時間")
	var s := Clock.state(24.0 * H - 1.0, 0.5)
	_eq_i(int(s["day_hours"]), 12, "1日 = 12時間")
	_eq_i(s["dial_number_count"], 6, "文字盤は1〜6")
	# 実23:59:59 → 拡張 11:59:59.5 → 表示は切り捨てで 11:59:59
	_eq_s(s["scaled_text"], "11:59:59", "1日の終わりは 11:59:59")
	var noon := Clock.state(12.0 * H, 0.5)
	_eq_s(noon["scaled_text"], "06:00:00", "実12:00 → 拡張06:00")
	_ok(noon["is_second_half"], "拡張06:00 は後半のはじまり(1日12時間なので)")


func test_midnight_resets() -> void:
	print("実0:00 で拡張時刻も 0:00 に戻る")
	for n in Clock.multiplier_choices():
		var s := Clock.state(0.0, n)
		_eq_s(s["scaled_text"], "00:00:00", "N=%.1f の 0:00" % n)
		_eq_f(s["hour_angle"], 0.0, "N=%.1f 時針が0" % n)
		_eq_f(s["minute_angle"], 0.0, "N=%.1f 分針が0" % n)
		_eq_f(s["second_angle"], 0.0, "N=%.1f 秒針が0" % n)
		_eq_f(s["day_progress"], 0.0, "N=%.1f 進捗が0" % n)


## 文字盤1周=12N時間、1日=24N時間 なので、時針は倍率に関係なく1日2周。
func test_hour_hand_turns_exactly_twice_per_day() -> void:
	print("時針は倍率に関係なく1日2周")
	for n in Clock.multiplier_choices():
		var turns := Clock.scaled_day_seconds(n) / Clock.hour_hand_period(n)
		_eq_f(turns, 2.0, "N=%.1f の時針の回転数" % n, 0.00001)
		# ちょうど半日で1周目が終わる
		var half := Clock.state(12.0 * H, n)
		_eq_f(half["hour_angle"], 0.0, "N=%.1f 実12:00で時針は12時方向" % n, 0.0001)


func test_minute_and_second_hand_periods() -> void:
	print("分針=拡張1時間で1周 / 秒針=拡張1分で1周")
	for n in Clock.multiplier_choices():
		# 拡張時刻で1時間ぶん進む実時間
		var real_per_scaled_hour := Clock.to_real_seconds(H, n)
		var s := Clock.state(real_per_scaled_hour, n)
		_eq_f(s["minute_angle"], 0.0, "N=%.1f 拡張1時間で分針1周" % n, 0.0001)
		var real_per_scaled_minute := Clock.to_real_seconds(60.0, n)
		var s2 := Clock.state(real_per_scaled_minute, n)
		_eq_f(s2["second_angle"], 0.0, "N=%.1f 拡張1分で秒針1周" % n, 0.0001)
		# 拡張時刻の1時間が実時間で何分か、と整合しているか
		_eq_f(
			real_per_scaled_hour / 60.0,
			Clock.real_minutes_per_scaled_hour(n),
			"N=%.1f 拡張1時間の実分数" % n
		)


func test_halves() -> void:
	print("前半 / 後半 の境界")
	for n in Clock.multiplier_choices():
		var boundary := Clock.to_real_seconds(Clock.scaled_day_seconds(n) * 0.5, n)
		_eq_f(boundary, 12.0 * H, "N=%.1f の境界は実12:00" % n)
		_ok(not Clock.is_second_half(Clock.to_scaled_seconds(boundary - 1.0, n), n), "N=%.1f 境界直前は前半" % n)
		_ok(Clock.is_second_half(Clock.to_scaled_seconds(boundary, n), n), "N=%.1f 境界は後半" % n)


func test_scaled_roundtrip() -> void:
	print("実秒 ↔ 拡張秒 の往復")
	for n in Clock.multiplier_choices():
		for real_sec in [0.0, 1.0, 12345.6, 43200.0, 86399.0]:
			var back := Clock.to_real_seconds(Clock.to_scaled_seconds(real_sec, n), n)
			_eq_f(back, real_sec, "N=%.1f real=%.1f の往復" % [n, real_sec], 0.0001)


func test_state_never_exceeds_day_length() -> void:
	print("拡張時刻は 24N 時間を超えない")
	for n in Clock.multiplier_choices():
		var last := Clock.state(Clock.REAL_DAY_SECONDS - 0.001, n)
		_ok(
			last["scaled_hour"] <= int(Clock.day_hours(n)) - 1,
			"N=%.1f の最大の時は %d (got %d)" % [n, int(Clock.day_hours(n)) - 1, last["scaled_hour"]]
		)
		_ok(last["day_progress"] < 1.0, "N=%.1f 進捗は1未満" % n)
