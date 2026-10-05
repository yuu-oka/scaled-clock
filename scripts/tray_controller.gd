extends RefCounted
class_name TrayController

## Windowsでタスクトレイに常駐させるための制御をまとめたクラス。
##
## DisplayServer のステータスインジケータ(トレイアイコン)機能が無いプラットフォーム
## (Linux/X11の一部構成や iOS など)では `available` が false のままになり、
## 何もしない。呼び出し側(main.gd)は `available` を見て、
## 「ウィンドウを閉じたら終了」という通常の挙動にフォールバックすること。
##
## iOS移植時の注意: トレイという概念自体がモバイルOSに存在しないため、
## このクラスは常に `available = false` で無害に終わる。トレイ前提の処理を
## 他のスクリプトに書かないこと(すべてこのクラス越しにする)。

var available := false

var _indicator_id := -1
var _menu_rid := RID()


## icon: トレイに出すアイコン。tooltip: ホバー時の説明文。
## on_toggle: 表示/非表示を切り替える(トレイアイコンのクリック、メニューの「表示/非表示」)
## on_settings: 設定画面を開く(メニューの「設定を開く」)
## on_quit: 完全終了する(メニューの「終了」)
func setup(
	icon: Texture2D, tooltip: String, on_toggle: Callable, on_settings: Callable, on_quit: Callable
) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		return

	_indicator_id = DisplayServer.create_status_indicator(icon, tooltip, Callable())
	# コールバックに渡される引数の数はプラットフォームによって変わりうるので
	# 可変長引数で受けて無視する(...argsはGDScript 2.0のrestパラメータ)。
	DisplayServer.status_indicator_set_callback(_indicator_id, func(...args): on_toggle.call())

	if NativeMenu.has_feature(NativeMenu.FEATURE_POPUP_MENU):
		_menu_rid = NativeMenu.create_menu()
		NativeMenu.add_item(_menu_rid, "表示 / 非表示", func(...args): on_toggle.call())
		NativeMenu.add_separator(_menu_rid)
		NativeMenu.add_item(_menu_rid, "設定を開く", func(...args): on_settings.call())
		NativeMenu.add_separator(_menu_rid)
		NativeMenu.add_item(_menu_rid, "終了", func(...args): on_quit.call())
		DisplayServer.status_indicator_set_menu(_indicator_id, _menu_rid)

	available = true


func set_tooltip(text: String) -> void:
	if available:
		DisplayServer.status_indicator_set_tooltip(_indicator_id, text)


## アプリ終了時に呼ぶ。トレイアイコン/メニューのOSリソースを解放する。
func teardown() -> void:
	if not available:
		return
	if _menu_rid.is_valid():
		NativeMenu.free_menu(_menu_rid)
	DisplayServer.delete_status_indicator(_indicator_id)
	available = false
