extends RefCounted
class_name SettingsStore

## 倍率などの設定を user:// に保存する。
## user:// は Windows / iOS / Android すべてでエンジンが適切な場所に割り当てるため、
## プラットフォーム固有のパスを書かない。

const PATH := "user://settings.cfg"
const SECTION := "clock"
const KEY_MULTIPLIER := "multiplier"
const KEY_SHOW_FACE := "show_face"
const KEY_FACE_MODE := "face_mode"


static func load_multiplier(fallback: float = 1.0) -> float:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return ScaledClock.clamp_multiplier(fallback)
	var raw: float = cfg.get_value(SECTION, KEY_MULTIPLIER, fallback)
	return ScaledClock.clamp_multiplier(raw)


static func save_multiplier(n: float) -> void:
	var cfg := ConfigFile.new()
	# 既存の値を保ったまま更新する(将来キーが増えても壊れないように)
	cfg.load(PATH)
	cfg.set_value(SECTION, KEY_MULTIPLIER, n)
	cfg.save(PATH)


## 文字盤(アナログ表示)を表示するかどうか。false なら非表示(デジタル表示のみ)。
static func load_show_face(fallback: bool = true) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return fallback
	return cfg.get_value(SECTION, KEY_SHOW_FACE, fallback)


static func save_show_face(show_face: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(SECTION, KEY_SHOW_FACE, show_face)
	cfg.save(PATH)


## 文字盤の表示方式(ScaledClock.FaceMode)。
static func load_face_mode(fallback: int = ScaledClock.FaceMode.HALF_DAY) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return fallback
	var raw: int = cfg.get_value(SECTION, KEY_FACE_MODE, fallback)
	if raw != ScaledClock.FaceMode.HALF_DAY and raw != ScaledClock.FaceMode.FULL_DAY:
		return fallback
	return raw


static func save_face_mode(mode: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(SECTION, KEY_FACE_MODE, mode)
	cfg.save(PATH)
