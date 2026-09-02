@tool
extends VBoxContainer

signal settings_requested
signal bell(count: int)
signal activated
signal notification_changed(has_unread: bool)
signal emptied

const TerminalPanel := preload("terminal_panel.gd")
const DEFAULT_FONT_SIZE := 14
const TOOLBAR_HEIGHT := 32.0
const MIN_TAB_WIDTH := 112.0
const MAX_TAB_WIDTH := 220.0
const MAX_TAB_TITLE_LENGTH := 32
const CLOSE_BUTTON_SIZE := 16.0
const TERMINAL_BACKGROUND := Color("181b22")
const TAB_BACKGROUND := Color("242424")
const TAB_HOVER_BACKGROUND := Color("1e2023")
const TOOLBAR_GLYPH_COLOR := Color("d8dee9")


class ToolbarGlyphButton extends Control:
	signal pressed

	enum Glyph { CLOSE, ADD }

	var _glyph := Glyph.ADD
	var _editor_scale := 1.0
	var _background := Color.TRANSPARENT
	var _hover_background := Color.TRANSPARENT
	var _hovered := false
	var _button_down := false


	func configure(
		glyph: Glyph, editor_scale: float, background: Color, hover_background: Color
	) -> void:
		_glyph = glyph
		_editor_scale = editor_scale
		set_background(background, hover_background)


	func set_background(background: Color, hover_background: Color) -> void:
		_background = background
		_hover_background = hover_background
		queue_redraw()


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)


	func _draw() -> void:
		var fill := _hover_background if _hovered else _background
		if _button_down:
			fill = fill.lightened(0.08)
		if fill.a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), fill)

		var center := size * 0.5
		var half_length := (3.5 if _glyph == Glyph.CLOSE else 6.5) * _editor_scale
		var thickness := (1.5 if _glyph == Glyph.CLOSE else 2.0) * _editor_scale
		if _glyph == Glyph.CLOSE:
			draw_line(
				center - Vector2.ONE * half_length,
				center + Vector2.ONE * half_length,
				TOOLBAR_GLYPH_COLOR,
				thickness,
				true
			)
			draw_line(
				center + Vector2(-half_length, half_length),
				center + Vector2(half_length, -half_length),
				TOOLBAR_GLYPH_COLOR,
				thickness,
				true
			)
		else:
			draw_line(
				center - Vector2(half_length, 0.0),
				center + Vector2(half_length, 0.0),
				TOOLBAR_GLYPH_COLOR,
				thickness,
				true
			)
			draw_line(
				center - Vector2(0.0, half_length),
				center + Vector2(0.0, half_length),
				TOOLBAR_GLYPH_COLOR,
				thickness,
				true
			)


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_button_down = true
			else:
				var should_press := _button_down and Rect2(Vector2.ZERO, size).has_point(
					event.position
				)
				_button_down = false
				if should_press:
					pressed.emit()
			queue_redraw()
			accept_event()


	func _on_mouse_entered() -> void:
		_hovered = true
		queue_redraw()


	func _on_mouse_exited() -> void:
		_hovered = false
		_button_down = false
		queue_redraw()

var _font_size := DEFAULT_FONT_SIZE
var _font_families := PackedStringArray([
	"Menlo", "Cascadia Mono", "DejaVu Sans Mono", "Liberation Mono", "monospace"
])
var _toolbar_content: Control
var _tab_viewport: Control
var _tab_bar: TabBar
var _close_button: ToolbarGlyphButton
var _add_button: ToolbarGlyphButton
var _settings_button: Button
var _terminal_stack: Control
var _terminals: Array[Control] = []
var _tab_titles: Array[String] = []
var _unread_terminal_ids := {}
var _hovered_tab := -1
var _next_terminal_id := 1
var _updating_tabs := false
var _tab_layout_queued := false
var _auto_close_exited := true


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_toolbar()
	_build_terminal_stack()
	_create_tab()


func _build_toolbar() -> void:
	var editor_scale := EditorInterface.get_editor_scale()
	var toolbar := PanelContainer.new()
	toolbar.name = "Toolbar"
	toolbar.custom_minimum_size.y = TOOLBAR_HEIGHT * editor_scale
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var toolbar_style := StyleBoxFlat.new()
	toolbar_style.bg_color = TAB_BACKGROUND
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		toolbar_style.set_content_margin(side, 0.0)
	toolbar.add_theme_stylebox_override("panel", toolbar_style)
	add_child(toolbar)

	_toolbar_content = Control.new()
	_toolbar_content.name = "ToolbarContent"
	_toolbar_content.resized.connect(_queue_tab_layout)
	toolbar.add_child(_toolbar_content)

	# A plain Control intentionally does not inherit the TabBar's full minimum
	# width. This lets us size it to its contents until overflow, then let the
	# TabBar show its native scrolling arrows without moving the utility buttons.
	_tab_viewport = Control.new()
	_tab_viewport.name = "TabViewport"
	_tab_viewport.clip_contents = true
	_tab_viewport.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tab_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_toolbar_content.add_child(_tab_viewport)

	_tab_bar = TabBar.new()
	_tab_bar.name = "Tabs"
	_tab_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tab_bar.clip_tabs = true
	_tab_bar.scrolling_enabled = true
	_tab_bar.scroll_to_selected = true
	_tab_bar.close_with_middle_mouse = true
	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
	_tab_bar.max_tab_width = roundi(MAX_TAB_WIDTH * editor_scale)
	_tab_bar.add_theme_stylebox_override(
		"tab_selected", _make_tab_style(TERMINAL_BACKGROUND, editor_scale)
	)
	_tab_bar.add_theme_stylebox_override(
		"tab_hovered", _make_tab_style(TAB_HOVER_BACKGROUND, editor_scale)
	)
	_tab_bar.add_theme_stylebox_override(
		"tab_unselected", _make_tab_style(TAB_BACKGROUND, editor_scale)
	)
	_tab_bar.add_theme_stylebox_override(
		"tab_disabled", _make_tab_style(TAB_BACKGROUND, editor_scale)
	)
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_tab_bar.tab_close_pressed.connect(_close_tab)
	_tab_bar.gui_input.connect(_on_tab_bar_gui_input)
	_tab_bar.mouse_exited.connect(_defer_hover_refresh)
	_tab_viewport.add_child(_tab_bar)

	_close_button = ToolbarGlyphButton.new()
	_close_button.name = "CloseHoveredTab"
	_close_button.configure(
		ToolbarGlyphButton.Glyph.CLOSE,
		editor_scale,
		TAB_HOVER_BACKGROUND,
		TAB_HOVER_BACKGROUND.lightened(0.08)
	)
	_close_button.tooltip_text = "Close terminal"
	_close_button.visible = false
	_close_button.custom_minimum_size = Vector2.ONE * CLOSE_BUTTON_SIZE * editor_scale
	_close_button.pressed.connect(_close_hovered_tab)
	_close_button.mouse_exited.connect(_defer_hover_refresh)
	_tab_viewport.add_child(_close_button)

	_add_button = ToolbarGlyphButton.new()
	_add_button.name = "AddTab"
	_add_button.configure(
		ToolbarGlyphButton.Glyph.ADD,
		editor_scale,
		Color.TRANSPARENT,
		TAB_HOVER_BACKGROUND
	)
	_add_button.custom_minimum_size = Vector2.ONE * TOOLBAR_HEIGHT * editor_scale
	_add_button.tooltip_text = "New terminal"
	_add_button.pressed.connect(_create_tab)
	_toolbar_content.add_child(_add_button)

	_settings_button = Button.new()
	_settings_button.name = "Settings"
	_settings_button.flat = true
	_settings_button.icon = get_theme_icon("Tools", "EditorIcons")
	_settings_button.tooltip_text = "Terminal settings"
	_settings_button.pressed.connect(settings_requested.emit)
	_toolbar_content.add_child(_settings_button)


func _make_tab_style(color: Color, editor_scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = roundi(5.0 * editor_scale)
	style.corner_radius_top_right = roundi(5.0 * editor_scale)
	style.set_content_margin(SIDE_LEFT, 12.0 * editor_scale)
	style.set_content_margin(SIDE_RIGHT, 12.0 * editor_scale)
	style.set_content_margin(SIDE_TOP, 5.0 * editor_scale)
	style.set_content_margin(SIDE_BOTTOM, 5.0 * editor_scale)
	return style


func _build_terminal_stack() -> void:
	_terminal_stack = Control.new()
	_terminal_stack.name = "TerminalStack"
	_terminal_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_terminal_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_terminal_stack)


func _create_tab() -> void:
	if not is_instance_valid(_terminal_stack):
		return
	var terminal := TerminalPanel.new()
	terminal.name = "TerminalCanvas%d" % _next_terminal_id
	_next_terminal_id += 1
	terminal.configure(_font_size, _font_families)
	terminal.bell.connect(_on_terminal_bell.bind(terminal))
	terminal.activated.connect(_on_terminal_activated.bind(terminal))
	terminal.title_changed.connect(_on_terminal_title_changed.bind(terminal))
	terminal.session_exited.connect(_on_terminal_session_exited.bind(terminal))
	_terminals.append(terminal)
	_tab_titles.append("Terminal")
	_tab_bar.add_tab("Terminal")
	_terminal_stack.add_child(terminal)
	terminal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_select_tab(_terminals.size() - 1, true)
	_queue_tab_layout()


func _close_tab(index: int) -> void:
	if index < 0 or index >= _terminals.size():
		return
	var old_current := _tab_bar.current_tab
	var terminal := _terminals[index]
	_set_hovered_tab(-1)
	_unread_terminal_ids.erase(terminal.get_instance_id())
	terminal.shutdown()
	terminal.queue_free()
	_updating_tabs = true
	_terminals.remove_at(index)
	_tab_titles.remove_at(index)
	_tab_bar.remove_tab(index)
	_updating_tabs = false

	if _terminals.is_empty():
		notification_changed.emit(false)
		call_deferred("_emit_emptied_if_empty")
	else:
		var next_index := old_current
		if index == old_current:
			next_index = mini(index, _terminals.size() - 1)
		elif index < old_current:
			next_index -= 1
		_select_tab(
			clampi(next_index, 0, _terminals.size() - 1), is_visible_in_tree()
		)
		notification_changed.emit(has_unread_notifications())
	_queue_tab_layout()


func _emit_emptied_if_empty() -> void:
	if _terminals.is_empty():
		emptied.emit()


func _select_tab(index: int, focus_terminal: bool) -> void:
	if index < 0 or index >= _terminals.size():
		return
	_updating_tabs = true
	_tab_bar.current_tab = index
	_updating_tabs = false
	for terminal_index in _terminals.size():
		_terminals[terminal_index].visible = terminal_index == index
	_tab_bar.ensure_tab_visible(index)
	if focus_terminal:
		_clear_terminal_notification(_terminals[index])
		_terminals[index].call_deferred("grab_focus")


func _on_tab_changed(index: int) -> void:
	if not _updating_tabs:
		_select_tab(index, true)


func _on_terminal_title_changed(title: String, terminal: Control) -> void:
	var index := _terminals.find(terminal)
	if index < 0:
		return
	var clean_title := title.replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()
	if clean_title.is_empty():
		clean_title = "Terminal"
	_tab_titles[index] = clean_title
	_tab_bar.set_tab_tooltip(index, clean_title)
	_queue_tab_layout()


func _truncate_title(title: String) -> String:
	if title.length() <= MAX_TAB_TITLE_LENGTH:
		return title
	return title.substr(0, MAX_TAB_TITLE_LENGTH - 1) + "…"


func _on_terminal_bell(count: int, terminal: Control) -> void:
	var index := _terminals.find(terminal)
	if index < 0:
		return
	# A focused terminal has already met the acknowledgement condition. Bells
	# from every other session remain unread until that exact tab is activated.
	if not terminal.has_focus() or not terminal.is_visible_in_tree():
		_unread_terminal_ids[terminal.get_instance_id()] = true
		_tab_bar.set_tab_icon(index, get_theme_icon("Error", "EditorIcons"))
		notification_changed.emit(true)
		_queue_tab_layout()
	bell.emit(count)


func _on_terminal_session_exited(terminal: Control) -> void:
	if _auto_close_exited:
		_close_tab(_terminals.find(terminal))


func _on_terminal_activated(terminal: Control) -> void:
	if _terminals.find(terminal) == _tab_bar.current_tab:
		_clear_terminal_notification(terminal)
	activated.emit()


func _clear_terminal_notification(terminal: Control) -> void:
	var index := _terminals.find(terminal)
	if index < 0:
		return
	if _unread_terminal_ids.erase(terminal.get_instance_id()):
		_tab_bar.set_tab_icon(index, null)
		notification_changed.emit(has_unread_notifications())
		_queue_tab_layout()


func has_unread_notifications() -> bool:
	return not _unread_terminal_ids.is_empty()


func activate_current_tab() -> void:
	if _tab_bar and _tab_bar.current_tab >= 0 and _tab_bar.current_tab < _terminals.size():
		var terminal := _terminals[_tab_bar.current_tab]
		_clear_terminal_notification(terminal)
		terminal.call_deferred("grab_focus")


func _on_tab_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered_tab(_tab_bar.get_tab_idx_at_point(event.position))


func _set_hovered_tab(index: int) -> void:
	if index == _hovered_tab:
		_position_close_button()
		return
	_hovered_tab = index
	_position_close_button()


func _refresh_hovered_tab() -> void:
	if not is_instance_valid(_tab_bar):
		return
	var mouse_position := _tab_bar.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, _tab_bar.size).has_point(mouse_position):
		_set_hovered_tab(-1)
		return
	_set_hovered_tab(_tab_bar.get_tab_idx_at_point(mouse_position))


func _defer_hover_refresh() -> void:
	_refresh_hovered_tab.call_deferred()


func _position_close_button() -> void:
	if not is_instance_valid(_close_button) or not is_instance_valid(_tab_bar):
		return
	if _hovered_tab < 0 or _hovered_tab >= _tab_bar.tab_count:
		_close_button.visible = false
		return
	var editor_scale := EditorInterface.get_editor_scale()
	var button_size := CLOSE_BUTTON_SIZE * editor_scale
	var margin := 5.0 * editor_scale
	var tab_rect := _tab_bar.get_tab_rect(_hovered_tab)
	_close_button.size = Vector2.ONE * button_size
	_close_button.position = Vector2(
		minf(tab_rect.end.x - button_size - margin, _tab_viewport.size.x - button_size - margin),
		tab_rect.position.y + (tab_rect.size.y - button_size) * 0.5
	)
	var background := (
		TERMINAL_BACKGROUND if _hovered_tab == _tab_bar.current_tab else TAB_HOVER_BACKGROUND
	)
	_close_button.set_background(background, background.lightened(0.08))
	_close_button.visible = true
	_close_button.move_to_front()


func _close_hovered_tab() -> void:
	var index := _hovered_tab
	_set_hovered_tab(-1)
	_close_tab(index)


func _queue_tab_layout() -> void:
	if _tab_layout_queued:
		return
	_tab_layout_queued = true
	_layout_tab_bar.call_deferred()


func _layout_tab_bar() -> void:
	_tab_layout_queued = false
	if not is_instance_valid(_tab_bar) or not is_instance_valid(_toolbar_content):
		return
	var add_button_size := _add_button.get_combined_minimum_size()
	var settings_button_size := _settings_button.get_combined_minimum_size()
	var fixed_width := add_button_size.x + settings_button_size.x
	var available_width := maxf(_toolbar_content.size.x - fixed_width, 0.0)
	var editor_scale := EditorInterface.get_editor_scale()
	var tab_count := _terminals.size()
	var target_tab_width := MAX_TAB_WIDTH * editor_scale
	if tab_count > 0:
		target_tab_width = clampf(
			available_width / tab_count,
			MIN_TAB_WIDTH * editor_scale,
			MAX_TAB_WIDTH * editor_scale
		)
	_tab_bar.max_tab_width = maxi(roundi(target_tab_width), 1)
	_update_display_titles(target_tab_width)
	var desired_width := target_tab_width * tab_count
	var viewport_width := minf(desired_width, available_width)
	_tab_viewport.position = Vector2.ZERO
	_tab_viewport.size = Vector2(viewport_width, _toolbar_content.size.y)
	_add_button.position = Vector2(viewport_width, 0.0)
	_add_button.size = Vector2(add_button_size.x, _toolbar_content.size.y)
	_settings_button.position = Vector2(
		_toolbar_content.size.x - settings_button_size.x, 0.0
	)
	_settings_button.size = Vector2(settings_button_size.x, _toolbar_content.size.y)
	_position_close_button()


func _update_display_titles(target_tab_width: float) -> void:
	if not is_instance_valid(_tab_bar):
		return
	var font := _tab_bar.get_theme_font("font")
	var font_size := _tab_bar.get_theme_font_size("font_size")
	var tab_style := _tab_bar.get_theme_stylebox("tab_unselected")
	var non_breaking_space := " "
	var space_width := maxf(
		font.get_string_size(
			non_breaking_space, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x,
		1.0
	)
	for index in _tab_titles.size():
		var title := _truncate_title(_tab_titles[index])
		var available_text_width := target_tab_width - tab_style.get_minimum_size().x
		var icon := _tab_bar.get_tab_icon(index)
		if icon:
			available_text_width -= icon.get_width() + _tab_bar.get_theme_constant("icon_separation")
		var title_width := font.get_string_size(
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x
		var padding_count := maxi(floori((available_text_width - title_width) / space_width), 0)
		var left_padding := padding_count >> 1
		var right_padding := padding_count - left_padding
		var display_title := (
			non_breaking_space.repeat(left_padding)
			+ title
			+ non_breaking_space.repeat(right_padding)
		)
		if _tab_bar.get_tab_title(index) != display_title:
			_tab_bar.set_tab_title(index, display_title)


func configure(
	font_size: int, font_families: PackedStringArray, auto_close_exited := true
) -> void:
	_font_size = clampi(font_size, 8, 72)
	_auto_close_exited = auto_close_exited
	if not font_families.is_empty():
		_font_families = font_families
	for terminal in _terminals:
		terminal.configure(_font_size, _font_families)


func shutdown() -> void:
	if not is_instance_valid(_tab_bar):
		return
	_updating_tabs = true
	for terminal in _terminals:
		terminal.shutdown()
		terminal.queue_free()
	_terminals.clear()
	_tab_titles.clear()
	_unread_terminal_ids.clear()
	_tab_bar.clear_tabs()
	_updating_tabs = false
	_hovered_tab = -1
	notification_changed.emit(false)
	_queue_tab_layout()


func start_session() -> void:
	if _terminals.is_empty():
		_create_tab()
	else:
		for terminal in _terminals:
			terminal.start_session()
		activate_current_tab()
