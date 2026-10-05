extends RefCounted
class_name SettingsStore

## 倍率などの設定を user:// に保存する。
## user:// は Windows / iOS / Android すべてでエンジンが適切な場所に割り当てるため、
## プラットフォーム固有のパスを書かない。

const PATH := "user://settings.cfg"
const SECTION := "clock"
const KEY_MULTIPLIER := "multiplier"


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
