extends RefCounted
class_name ScaledClock

## 倍速時計のロジック。
##
## 描画やUIには一切依存しない純粋な計算のみを持つ(すべて static)ので、
## tests/test_scaled_clock.gd からヘッドレスで単体テストできる。
##
## 用語:
##   real_sec   実世界の「その日の0:00からの経過秒」(0 <= real_sec < 86400)
##   scaled_sec 拡張時刻の「その日の0:00からの経過秒」= real_sec * N
##   N          倍率 (0.5〜3.0, 0.5刻み)
##
## 定義:
##   1日            = 24 * N 時間 (拡張時刻)
##   拡張時刻の1時間 = 実時間 60 / N 分
##
## 文字盤の表示方式(FaceMode)は2通り選べる:
##   HALF_DAY … 文字盤1周 = 12 * N 時間 → 1日で時針は2周(AM/PM表示。既定)
##   FULL_DAY … 文字盤1周 = 24 * N 時間 → 1日で時針はちょうど1周(24時間表示)

const MIN_MULTIPLIER := 0.5
const MAX_MULTIPLIER := 3.0
const MULTIPLIER_STEP := 0.5

enum FaceMode { HALF_DAY, FULL_DAY }

const REAL_DAY_SECONDS := 86400.0
const SECONDS_PER_HOUR := 3600.0
const SECONDS_PER_MINUTE := 60.0
## 倍率1のときの文字盤1周の時間数(=通常のアナログ時計)
const DIAL_HOURS_AT_X1 := 12.0


## 倍率を 0.5 刻みに丸めて 0.5〜3.0 に収める。
static func clamp_multiplier(n: float) -> float:
	var snapped_value := roundf(n / MULTIPLIER_STEP) * MULTIPLIER_STEP
	return clampf(snapped_value, MIN_MULTIPLIER, MAX_MULTIPLIER)


## 選択可能な倍率の一覧 [0.5, 1.0, ... 3.0]。
static func multiplier_choices() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := MIN_MULTIPLIER
	while n <= MAX_MULTIPLIER + 0.0001:
		out.append(n)
		n += MULTIPLIER_STEP
	return out


## 1日の長さ(拡張時刻の時間数)。N=2 なら 48。
static func day_hours(n: float) -> float:
	return 24.0 * n


## 文字盤1周の時間数(拡張時刻)。
## HALF_DAY: N=2 なら 24(1日2周)。FULL_DAY: N=2 なら 48(1日1周、day_hoursと同じ)。
static func dial_hours(n: float, face_mode: int = FaceMode.HALF_DAY) -> float:
	if face_mode == FaceMode.FULL_DAY:
		return day_hours(n)
	return DIAL_HOURS_AT_X1 * n


## 文字盤に並べる数字の個数(=最大の数字)。
## HALF_DAY: N=2 なら 24(1〜24)。FULL_DAY: N=2 なら 48(1〜48)。
static func dial_number_count(n: float, face_mode: int = FaceMode.HALF_DAY) -> int:
	return int(roundf(dial_hours(n, face_mode)))


## 拡張時刻の1時間が実時間で何分か。N=2 なら 30。
static func real_minutes_per_scaled_hour(n: float) -> float:
	return 60.0 / n


## 1日ぶんの拡張秒数。
static func scaled_day_seconds(n: float) -> float:
	return REAL_DAY_SECONDS * n


## 時針が1周するのに必要な拡張秒数。
static func hour_hand_period(n: float, face_mode: int = FaceMode.HALF_DAY) -> float:
	return dial_hours(n, face_mode) * SECONDS_PER_HOUR


## 実経過秒から拡張経過秒へ。
static func to_scaled_seconds(real_sec: float, n: float) -> float:
	return real_sec * n


## 拡張経過秒から実経過秒へ(逆変換)。
static func to_real_seconds(scaled_sec: float, n: float) -> float:
	return scaled_sec / n


## 文字盤の針の角度。12時方向を0とし、時計回りを正とするラジアン。
static func hand_angle(scaled_sec: float, period_sec: float) -> float:
	return TAU * fposmod(scaled_sec, period_sec) / period_sec


## 拡張時刻を 時/分/秒 に分解する。hour は 0〜(24N - 1)。
static func split_scaled_time(scaled_sec: float) -> Dictionary:
	var total := int(floor(scaled_sec))
	return {
		"hour": total / 3600,
		"minute": (total / 60) % 60,
		"second": total % 60,
	}


## "31:25:08" 形式。
static func format_clock(hour: int, minute: int, second: int) -> String:
	return "%02d:%02d:%02d" % [hour, minute, second]


## 1日の後半かどうか(通常のPMに相当)。
static func is_second_half(scaled_sec: float, n: float) -> bool:
	return scaled_sec >= scaled_day_seconds(n) * 0.5


## AM/PM相当のラベル。
static func half_label(scaled_sec: float, n: float) -> String:
	return "後半" if is_second_half(scaled_sec, n) else "前半"


## 時計の全状態をまとめて返す。描画・UIはこれだけを見ればよい。
static func state(real_sec: float, n: float, face_mode: int = FaceMode.HALF_DAY) -> Dictionary:
	var scaled_sec := to_scaled_seconds(real_sec, n)
	var scaled_parts := split_scaled_time(scaled_sec)
	var real_parts := split_scaled_time(real_sec)
	return {
		"multiplier": n,
		"face_mode": face_mode,
		"real_sec": real_sec,
		"scaled_sec": scaled_sec,
		"scaled_hour": scaled_parts["hour"],
		"scaled_minute": scaled_parts["minute"],
		"scaled_second": scaled_parts["second"],
		"scaled_text": format_clock(
			scaled_parts["hour"], scaled_parts["minute"], scaled_parts["second"]
		),
		"real_text": format_clock(
			real_parts["hour"], real_parts["minute"], real_parts["second"]
		),
		"day_hours": day_hours(n),
		"dial_hours": dial_hours(n, face_mode),
		"dial_number_count": dial_number_count(n, face_mode),
		"real_minutes_per_scaled_hour": real_minutes_per_scaled_hour(n),
		"day_progress": fposmod(scaled_sec, scaled_day_seconds(n)) / scaled_day_seconds(n),
		"is_second_half": is_second_half(scaled_sec, n),
		"half_label": half_label(scaled_sec, n),
		# 12時方向=0、時計回り正のラジアン
		"hour_angle": hand_angle(scaled_sec, hour_hand_period(n, face_mode)),
		"minute_angle": hand_angle(scaled_sec, SECONDS_PER_HOUR),
		"second_angle": hand_angle(scaled_sec, SECONDS_PER_MINUTE),
	}


## システムのローカル時刻から real_sec を得る(サブ秒精度つき)。
## OS依存のコマンドやパスは使わず Time クラスのみを使うので全プラットフォームで動く。
static func real_seconds_now() -> float:
	var utc_unix := Time.get_unix_time_from_system()
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	return fposmod(utc_unix + bias_minutes * 60.0, REAL_DAY_SECONDS)
