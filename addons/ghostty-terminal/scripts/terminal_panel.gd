@tool
extends Control

signal bell(count: int)
signal activated
signal title_changed(title: String)
signal session_exited

const DEFAULT_FONT_SIZE := 14
const PADDING := 6.0
const SCROLLBAR_WIDTH := 16.0
const RESIZE_DEBOUNCE_SECONDS := 0.08
const TITLE_REFRESH_SECONDS := 0.5
const SCROLL_ROWS_PER_WHEEL_STEP := 3.0
const STYLE_BOLD := 1
const STYLE_ITALIC := 1 << 1
const STYLE_UNDERLINE := 1 << 2
const STYLE_STRIKETHROUGH := 1 << 3
const MENU_COPY := 1
const MENU_PASTE := 2
const MENU_SELECT_ALL := 3
const SHORTCUT_OPEN_TERMINAL := "ghostty_terminal/open_terminal"
const SHORTCUT_COPY := "ghostty_terminal/copy"
const SHORTCUT_PASTE := "ghostty_terminal/paste"

var _session: GhosttyTerminalSession
var _fonts: Array[SystemFont] = []
var _font_size := DEFAULT_FONT_SIZE
var _font_families := PackedStringArray([
	"Menlo", "Cascadia Mono", "DejaVu Sans Mono", "Liberation Mono", "monospace"
])
var _render_font_size := DEFAULT_FONT_SIZE
var _padding := PADDING
var _cell_size := Vector2.ONE
var _background: ColorRect
var _scrollbar: VScrollBar
var _updating_scrollbar := false
var _resize_timer: Timer
var _frame := {}
var _error_message := ""
var _selecting := false
var _scroll_accumulator := 0.0
var _menu: PopupMenu
var _title := ""
var _title_refresh_elapsed := 0.0
var _exit_reported := false


func _ready() -> void:
	set_process(true)
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_IBEAM
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_entered.connect(activated.emit)
	var editor_scale := EditorInterface.get_editor_scale()
	_render_font_size = maxi(roundi(_font_size * editor_scale), 1)
	_padding = PADDING * editor_scale

	_background = ColorRect.new()
	_background.color = Color("181b22")
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.show_behind_parent = true
	add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_scrollbar = VScrollBar.new()
	_scrollbar.name = "ScrollBar"
	_scrollbar.anchor_left = 1.0
	_scrollbar.anchor_right = 1.0
	_scrollbar.anchor_bottom = 1.0
	_scrollbar.step = 1.0
	_scrollbar.visible = false
	_scrollbar.value_changed.connect(_on_scrollbar_value_changed)
	add_child(_scrollbar)

	_rebuild_fonts()

	_menu = PopupMenu.new()
	_menu.add_item("Copy", MENU_COPY)
	_menu.add_item("Paste", MENU_PASTE)
	_menu.add_separator()
	_menu.add_item("Select All", MENU_SELECT_ALL)
	_menu.id_pressed.connect(_on_menu_item_pressed)
	add_child(_menu)

	_resize_timer = Timer.new()
	_resize_timer.one_shot = true
	_resize_timer.wait_time = RESIZE_DEBOUNCE_SECONDS
	_resize_timer.timeout.connect(_apply_terminal_size)
	add_child(_resize_timer)

	resized.connect(_queue_terminal_resize)
	start_session()


func start_session() -> void:
	if _session:
		return
	_frame = {}
	_error_message = ""
	_exit_reported = false
	_session = GhosttyTerminalSession.new()
	_apply_terminal_size()
	if not _session.start_session(ProjectSettings.globalize_path("res://")):
		# Keep startup errors visible instead of treating them as a shell that
		# started successfully and then exited.
		_exit_reported = true
		_show_error(_session.error_message())
	else:
		_refresh_frame()
		_refresh_title(true)


func _create_font(weight: int, italic: bool) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = _font_families
	font.allow_system_fallback = true
	font.font_weight = weight
	font.font_italic = italic
	return font


func configure(font_size: int, font_families: PackedStringArray) -> void:
	_font_size = clampi(font_size, 8, 72)
	if not font_families.is_empty():
		_font_families = font_families
	if is_node_ready():
		_rebuild_fonts()
		_apply_terminal_size()


func _rebuild_fonts() -> void:
	_render_font_size = maxi(roundi(_font_size * EditorInterface.get_editor_scale()), 1)
	_fonts = [
		_create_font(400, false),
		_create_font(700, false),
		_create_font(400, true),
		_create_font(700, true),
	]
	_cell_size = Vector2.ONE
	for font in _fonts:
		_cell_size.x = maxf(
			_cell_size.x,
			font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, _render_font_size).x
		)
		_cell_size.y = maxf(_cell_size.y, font.get_height(_render_font_size))
	_cell_size = Vector2(ceilf(_cell_size.x), ceilf(_cell_size.y))
	queue_redraw()


func shutdown() -> void:
	if _session:
		_session.stop_session()
		_session = null


func is_session_running() -> bool:
	return _session != null and _session.is_session_running()


func _process(delta: float) -> void:
	if not _session:
		return
	var changed := _session.poll()
	_title_refresh_elapsed += delta
	if _title_refresh_elapsed >= TITLE_REFRESH_SECONDS:
		_title_refresh_elapsed = 0.0
		_refresh_title()
	var bell_count := _session.take_bell_count()
	if bell_count > 0:
		bell.emit(bell_count)
	if changed:
		_refresh_frame()
	if not _session.is_session_running():
		if not _session.error_message().is_empty():
			_show_error(_session.error_message())
		if not _exit_reported:
			_exit_reported = true
			session_exited.emit()


func _refresh_title(force := false) -> void:
	if not _session:
		return
	var title := String(_session.display_title())
	if force or title != _title:
		_title = title
		title_changed.emit(title)


func _draw() -> void:
	if not _error_message.is_empty():
		draw_string(
			_fonts[0], Vector2(_padding, _padding + _fonts[0].get_ascent(_render_font_size)),
			_error_message, HORIZONTAL_ALIGNMENT_LEFT, -1, _render_font_size, Color("f28b82")
		)
		return
	if _frame.is_empty():
		return

	var background_geometry: PackedInt32Array = _frame.get(
		"background_geometry", PackedInt32Array()
	)
	var background_colors: PackedColorArray = _frame.get(
		"background_colors", PackedColorArray()
	)
	for index in background_colors.size():
		var geometry_index := index * 3
		var row := background_geometry[geometry_index]
		var column := background_geometry[geometry_index + 1]
		var length := background_geometry[geometry_index + 2]
		var position := Vector2(_padding + column * _cell_size.x, _padding + row * _cell_size.y)
		draw_rect(Rect2(position, Vector2(length * _cell_size.x, _cell_size.y)), background_colors[index])

	var glyph_geometry: PackedInt32Array = _frame.get("glyph_geometry", PackedInt32Array())
	var glyph_text: PackedStringArray = _frame.get("glyph_text", PackedStringArray())
	var glyph_colors: PackedColorArray = _frame.get("glyph_colors", PackedColorArray())
	for index in glyph_text.size():
		var geometry_index := index * 3
		var row := glyph_geometry[geometry_index]
		var column := glyph_geometry[geometry_index + 1]
		var flags := glyph_geometry[geometry_index + 2]
		var font_index := (1 if flags & STYLE_BOLD else 0) + (2 if flags & STYLE_ITALIC else 0)
		var font := _fonts[font_index]
		var baseline := Vector2(
			_padding + column * _cell_size.x,
			_padding + row * _cell_size.y + font.get_ascent(_render_font_size)
		)
		draw_string(
			font, baseline, glyph_text[index], HORIZONTAL_ALIGNMENT_LEFT,
			_cell_size.x, _render_font_size, glyph_colors[index]
		)

	var decoration_geometry: PackedInt32Array = _frame.get(
		"decoration_geometry", PackedInt32Array()
	)
	var decoration_colors: PackedColorArray = _frame.get(
		"decoration_colors", PackedColorArray()
	)
	for index in decoration_colors.size():
		var geometry_index := index * 3
		var row := decoration_geometry[geometry_index]
		var column := decoration_geometry[geometry_index + 1]
		var flags := decoration_geometry[geometry_index + 2]
		var x := _padding + column * _cell_size.x
		var y := _padding + row * _cell_size.y
		if flags & STYLE_UNDERLINE != 0:
			var underline_y := y + _fonts[0].get_ascent(_render_font_size) + 1.0
			draw_line(
				Vector2(x, underline_y), Vector2(x + _cell_size.x, underline_y),
				decoration_colors[index], maxf(_fonts[0].get_underline_thickness(_render_font_size), 1.0)
			)
		if flags & STYLE_STRIKETHROUGH != 0:
			var strike_y := y + _cell_size.y * 0.5
			draw_line(
				Vector2(x, strike_y), Vector2(x + _cell_size.x, strike_y),
				decoration_colors[index], 1.0
			)


func _queue_terminal_resize() -> void:
	if _resize_timer:
		_resize_timer.start()


func _apply_terminal_size() -> void:
	if not _session:
		return
	var available := Vector2(
		maxf(size.x - _padding * 2.0 - _scrollbar_width(), 1.0),
		maxf(size.y - _padding * 2.0, 1.0)
	)
	var columns := clampi(floori(available.x / _cell_size.x), 1, 65535)
	var rows := clampi(floori(available.y / _cell_size.y), 1, 65535)
	var pixel_width := clampi(roundi(columns * _cell_size.x), 1, 65535)
	var pixel_height := clampi(roundi(rows * _cell_size.y), 1, 65535)
	_session.resize(columns, rows, pixel_width, pixel_height)
	_refresh_frame()


func _refresh_frame() -> void:
	if not _session:
		return
	var next_frame := _session.render_frame()
	if not next_frame.is_empty():
		_frame = next_frame
		_background.color = _frame.get("background", Color("181b22"))
		_update_scrollbar()
		_error_message = ""
		queue_redraw()
	elif not _session.error_message().is_empty():
		_show_error(_session.error_message())


func _gui_input(event: InputEvent) -> void:
	if not _session:
		return
	if event is InputEventMouseButton or event is InputEventKey or event is InputEventPanGesture:
		activated.emit()

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_scroll_by(-maxi(1, roundi(SCROLL_ROWS_PER_WHEEL_STEP * mouse_event.factor)))
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_scroll_by(maxi(1, roundi(SCROLL_ROWS_PER_WHEEL_STEP * mouse_event.factor)))
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var cell := _cell_at(mouse_event.position)
			if mouse_event.pressed:
				grab_focus()
				_selecting = _session.selection_press(
					cell.x, cell.y, mouse_event.position.x, mouse_event.position.y, _cell_size.x
				)
			else:
				_session.selection_release(cell.x, cell.y)
				_selecting = false
			_refresh_frame()
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			grab_focus()
			_menu.set_item_disabled(_menu.get_item_index(MENU_COPY), _session.selected_text().is_empty())
			var screen_position := get_screen_transform() * mouse_event.position
			_menu.position = Vector2i(screen_position)
			_menu.popup()
			accept_event()
			return

	if event is InputEventPanGesture:
		var pan_event := event as InputEventPanGesture
		_scroll_accumulator += pan_event.delta.y * SCROLL_ROWS_PER_WHEEL_STEP
		var rows := int(_scroll_accumulator)
		if rows != 0:
			_scroll_accumulator -= rows
			_scroll_by(rows)
		accept_event()
		return

	if event is InputEventMouseMotion and _selecting:
		var motion_event := event as InputEventMouseMotion
		var cell := _cell_at(motion_event.position)
		_session.selection_drag(
			cell.x, cell.y, motion_event.position.x, motion_event.position.y, _cell_size.x,
			_padding, size.y, motion_event.alt_pressed
		)
		_refresh_frame()
		accept_event()
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	var editor_settings := EditorInterface.get_editor_settings()
	if (
		key_event.pressed
		and not key_event.echo
		and editor_settings.is_shortcut(SHORTCUT_OPEN_TERMINAL, event)
	):
		# Leave the event unhandled for Godot's EditorDock shortcut handler.
		return
	if key_event.pressed and not key_event.echo and editor_settings.is_shortcut(
		SHORTCUT_COPY, event
	):
		_copy_selection()
		accept_event()
		return
	if key_event.pressed and not key_event.echo and editor_settings.is_shortcut(
		SHORTCUT_PASTE, event
	):
		_paste_clipboard()
		accept_event()
		return
	if key_event.pressed and key_event.meta_pressed and key_event.keycode == KEY_A:
		if _session.select_all():
			_refresh_frame()
		accept_event()
		return

	var action := 0 if not key_event.pressed else (2 if key_event.echo else 1)
	var modifiers := (
		int(key_event.shift_pressed)
		| (int(key_event.ctrl_pressed) << 1)
		| (int(key_event.alt_pressed) << 2)
		| (int(key_event.meta_pressed) << 3)
	)
	if _session.send_key(key_event.keycode, key_event.unicode, action, modifiers):
		if key_event.pressed:
			_session.clear_selection()
			_refresh_frame()
		accept_event()


func _cell_at(position: Vector2) -> Vector2i:
	var columns: int = _frame.get("cols", 1)
	var rows: int = _frame.get("rows", 1)
	return Vector2i(
		clampi(floori((position.x - _padding) / _cell_size.x), 0, maxi(columns, 0)),
		clampi(floori((position.y - _padding) / _cell_size.y), 0, maxi(rows, 0))
	)


func _scrollbar_width() -> float:
	if _scrollbar and _scrollbar.visible:
		return maxf(
			_scrollbar.get_combined_minimum_size().x,
			SCROLLBAR_WIDTH * EditorInterface.get_editor_scale()
		)
	return SCROLLBAR_WIDTH * EditorInterface.get_editor_scale()


func _scroll_by(rows: int) -> void:
	if rows != 0 and _session.scroll(rows):
		_refresh_frame()


func _on_scrollbar_value_changed(value: float) -> void:
	if not _updating_scrollbar and _session and _session.scroll_to(roundi(value)):
		_refresh_frame()


func _update_scrollbar() -> void:
	if not _scrollbar:
		return
	_updating_scrollbar = true
	var total := maxi(int(_frame.get("scroll_total", 0)), 1)
	var page := clampi(int(_frame.get("scroll_page", 1)), 1, total)
	var should_show := total > page
	if _scrollbar.visible != should_show:
		_scrollbar.visible = should_show
		if should_show:
			_scrollbar.offset_left = -_scrollbar_width()
		_queue_terminal_resize()
	_scrollbar.max_value = total
	_scrollbar.page = page
	_scrollbar.value = clampi(int(_frame.get("scroll_offset", 0)), 0, total - page)
	_updating_scrollbar = false


func _copy_selection() -> void:
	var selected_text := _session.selected_text()
	if not selected_text.is_empty():
		DisplayServer.clipboard_set(selected_text)


func _paste_clipboard() -> void:
	if _session.paste(DisplayServer.clipboard_get()):
		_session.clear_selection()
		_refresh_frame()


func _on_menu_item_pressed(id: int) -> void:
	match id:
		MENU_COPY:
			_copy_selection()
		MENU_PASTE:
			_paste_clipboard()
		MENU_SELECT_ALL:
			if _session.select_all():
				_refresh_frame()


func _show_error(message: String) -> void:
	_error_message = message
	queue_redraw()
