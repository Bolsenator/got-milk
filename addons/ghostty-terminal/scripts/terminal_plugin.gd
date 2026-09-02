@tool
extends EditorPlugin

const TerminalDock := preload("terminal_dock.gd")
const TerminalSettingsDialog := preload("terminal_settings_dialog.gd")
const METADATA_SECTION := "ghostty_terminal"
const DEFAULT_FONT_SIZE := 14
const DEFAULT_BELL_SOUND_ENABLED := true
const DEFAULT_AUTO_CLOSE_EXITED := true
const BELL_SOUND_COOLDOWN_MSEC := 100
const EDITOR_DOCK_LAYOUT_ALL := 7
const EDITOR_DOCK_SLOT_BOTTOM := 8
const SHORTCUT_OPEN_TERMINAL := "ghostty_terminal/open_terminal"
const SHORTCUT_COPY := "ghostty_terminal/copy"
const SHORTCUT_PASTE := "ghostty_terminal/paste"
const DEFAULT_FONT_FAMILIES := [
	"Menlo", "Cascadia Mono", "DejaVu Sans Mono", "Liberation Mono", "monospace"
]

var _terminal: Control
var _settings_dialog: ConfirmationDialog
var _bottom_panel_button: Button
var _editor_dock: Control
var _uses_editor_dock := false
var _last_bell_sound_msec := -BELL_SOUND_COOLDOWN_MSEC
var _bell_sound_enabled := DEFAULT_BELL_SOUND_ENABLED


func _enter_tree() -> void:
	if not ClassDB.class_exists("GhosttyTerminalSession"):
		push_error("Ghostty Terminal: the Rust GDExtension did not register GhosttyTerminalSession")
		return

	# CI starts the editor with the headless display server. Constructing the
	# class proves the native library loaded without spawning a shell process.
	if DisplayServer.get_name() == "headless":
		var smoke_session := GhosttyTerminalSession.new()
		if smoke_session.self_test():
			print("GHOSTTY_TERMINAL_LOAD_OK ", smoke_session.backend_name())
		else:
			push_error("Ghostty Terminal: libghostty self-test failed")
		return
	_register_shortcuts()

	_settings_dialog = TerminalSettingsDialog.new()
	_settings_dialog.confirmed.connect(_apply_settings)
	get_editor_interface().get_base_control().add_child(_settings_dialog)

	_terminal = TerminalDock.new()
	_terminal.name = "Terminal"
	_terminal.custom_minimum_size = Vector2(0, 220)
	var preferences := _load_settings()
	_bell_sound_enabled = preferences.bell_sound_enabled
	_terminal.configure(
		preferences.font_size, preferences.font_families, preferences.auto_close_exited
	)
	_terminal.settings_requested.connect(_show_settings)
	_terminal.bell.connect(_on_terminal_bell)
	_terminal.notification_changed.connect(_on_terminal_notification_changed)
	_terminal.emptied.connect(_on_terminal_emptied)
	_terminal.visibility_changed.connect(_on_terminal_visibility_changed)
	_add_terminal_to_editor()


func _exit_tree() -> void:
	if is_instance_valid(_settings_dialog):
		_settings_dialog.queue_free()
	_settings_dialog = null
	if is_instance_valid(_terminal):
		_terminal.shutdown()
		if _uses_editor_dock and is_instance_valid(_editor_dock):
			call("remove_dock", _editor_dock)
			_editor_dock.queue_free()
		else:
			remove_control_from_bottom_panel(_terminal)
			_terminal.queue_free()
	_terminal = null
	_bottom_panel_button = null
	_editor_dock = null
	_uses_editor_dock = false


func _register_shortcuts() -> void:
	var editor_settings := EditorInterface.get_editor_settings()
	_register_shortcut(
		editor_settings,
		SHORTCUT_OPEN_TERMINAL,
		"Open Terminal",
		_make_shortcut(KEY_QUOTELEFT, false)
	)
	_register_shortcut(
		editor_settings, SHORTCUT_COPY, "Copy", _make_shortcut(KEY_C, true)
	)
	_register_shortcut(
		editor_settings, SHORTCUT_PASTE, "Paste", _make_shortcut(KEY_V, true)
	)


func _register_shortcut(
	editor_settings: EditorSettings, path: String, display_name: String, shortcut: Shortcut
) -> void:
	shortcut.resource_name = display_name
	editor_settings.add_shortcut(path, shortcut)
	# add_shortcut() preserves an already-customized Shortcut resource. Set its
	# display name as well when the editor retained that existing resource.
	editor_settings.get_shortcut(path).resource_name = display_name


func _make_shortcut(keycode: Key, command_or_control_autoremap: bool) -> Shortcut:
	var event := InputEventKey.new()
	event.keycode = keycode
	if command_or_control_autoremap:
		event.command_or_control_autoremap = true
	else:
		event.ctrl_pressed = true
	var shortcut := Shortcut.new()
	shortcut.events = [event]
	return shortcut


func _add_terminal_to_editor() -> void:
	# EditorDock is available in newer Godot versions. Instantiate it dynamically
	# so the plugin can retain its legacy bottom-panel fallback on Godot 4.5.
	if ClassDB.class_exists("EditorDock") and has_method("add_dock"):
		var dock := ClassDB.instantiate("EditorDock") as Control
		if is_instance_valid(dock):
			dock.name = "GhosttyTerminalDock"
			dock.set("title", "Terminal")
			dock.set("layout_key", "ghostty_terminal")
			dock.set("default_slot", EDITOR_DOCK_SLOT_BOTTOM)
			dock.set("available_layouts", EDITOR_DOCK_LAYOUT_ALL)
			dock.set("global", true)
			dock.set(
				"dock_shortcut",
				EditorInterface.get_editor_settings().get_shortcut(SHORTCUT_OPEN_TERMINAL)
			)
			dock.connect("closed", _on_editor_dock_closed)
			dock.connect("opened", _on_editor_dock_opened)
			dock.add_child(_terminal)
			call("add_dock", dock)
			_editor_dock = dock
			_uses_editor_dock = true
			return

	_bottom_panel_button = add_control_to_bottom_panel(
		_terminal,
		"Terminal",
		EditorInterface.get_editor_settings().get_shortcut(SHORTCUT_OPEN_TERMINAL)
	)
	_editor_dock = _terminal.get_parent() as Control


func _on_editor_dock_closed() -> void:
	_clear_terminal_notification()
	if is_instance_valid(_terminal):
		_terminal.shutdown()


func _on_editor_dock_opened() -> void:
	if is_instance_valid(_terminal):
		_terminal.start_session()


func _on_terminal_bell(_count: int) -> void:
	var now := Time.get_ticks_msec()
	if _bell_sound_enabled and now - _last_bell_sound_msec >= BELL_SOUND_COOLDOWN_MSEC:
		DisplayServer.beep()
		_last_bell_sound_msec = now


func _on_terminal_notification_changed(has_unread: bool) -> void:
	_set_terminal_notification(has_unread)


func _set_terminal_notification(visible: bool) -> void:
	var notification_icon := get_editor_interface().get_editor_theme().get_icon(
		"Error", "EditorIcons"
	)
	if is_instance_valid(_editor_dock) and _editor_dock.has_method("set_dock_icon"):
		_editor_dock.call("set_dock_icon", notification_icon if visible else null)
		_editor_dock.call("set_force_show_icon", visible)
	elif is_instance_valid(_bottom_panel_button):
		# Before EditorDock, this API returned the actual visible bottom-panel button.
		_bottom_panel_button.icon = notification_icon if visible else null


func _clear_terminal_notification() -> void:
	_set_terminal_notification(false)


func _on_terminal_visibility_changed() -> void:
	if is_instance_valid(_terminal) and _terminal.is_visible_in_tree():
		_terminal.start_session()
		_terminal.activate_current_tab()
		_set_terminal_notification(_terminal.has_unread_notifications())


func _on_terminal_emptied() -> void:
	# Collapsing the bottom panel retains the registered EditorDock and its
	# button. EditorDock.close() is reserved for the user's explicit Close
	# action, which intentionally removes the dock and destroys all sessions.
	var dock_parent := _editor_dock.get_parent() if is_instance_valid(_editor_dock) else null
	if dock_parent is TabContainer and dock_parent.tabs_position == TabContainer.POSITION_BOTTOM:
		hide_bottom_panel()


func _show_settings() -> void:
	var preferences := _load_settings()
	_settings_dialog.set_values(
		preferences.font_size,
		preferences.font_families,
		preferences.bell_sound_enabled,
		preferences.auto_close_exited
	)
	_settings_dialog.reset_size()
	_settings_dialog.popup_centered()


func _apply_settings() -> void:
	var font_size: int = _settings_dialog.get_font_size()
	var font_families: PackedStringArray = _settings_dialog.get_font_families()
	var bell_sound_enabled: bool = _settings_dialog.is_bell_sound_enabled()
	var auto_close_exited: bool = _settings_dialog.is_auto_close_exited_enabled()
	var editor_settings := get_editor_interface().get_editor_settings()
	editor_settings.set_project_metadata(METADATA_SECTION, "font_size", font_size)
	editor_settings.set_project_metadata(METADATA_SECTION, "font_families", font_families)
	editor_settings.set_project_metadata(
		METADATA_SECTION, "bell_sound_enabled", bell_sound_enabled
	)
	editor_settings.set_project_metadata(
		METADATA_SECTION, "auto_close_exited", auto_close_exited
	)
	_bell_sound_enabled = bell_sound_enabled
	if is_instance_valid(_terminal):
		_terminal.configure(font_size, font_families, auto_close_exited)


func _load_settings() -> Dictionary:
	var editor_settings := get_editor_interface().get_editor_settings()
	var font_size := int(editor_settings.get_project_metadata(
		METADATA_SECTION, "font_size", DEFAULT_FONT_SIZE
	))
	var stored_families = editor_settings.get_project_metadata(
		METADATA_SECTION, "font_families", DEFAULT_FONT_FAMILIES
	)
	var font_families := PackedStringArray(stored_families)
	if font_families.is_empty():
		font_families = PackedStringArray(DEFAULT_FONT_FAMILIES)
	var bell_sound_enabled := bool(editor_settings.get_project_metadata(
		METADATA_SECTION, "bell_sound_enabled", DEFAULT_BELL_SOUND_ENABLED
	))
	var auto_close_exited := bool(editor_settings.get_project_metadata(
		METADATA_SECTION, "auto_close_exited", DEFAULT_AUTO_CLOSE_EXITED
	))
	return {
		"font_size": clampi(font_size, 8, 72),
		"font_families": font_families,
		"bell_sound_enabled": bell_sound_enabled,
		"auto_close_exited": auto_close_exited,
	}
