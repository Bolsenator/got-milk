@tool
extends ConfirmationDialog

const DEFAULT_FONT_SIZE := 14

var _font_size: SpinBox
var _font_families: LineEdit
var _bell_sound: CheckBox
var _auto_close_exited: CheckBox


func _ready() -> void:
	title = "Ghostty Terminal Settings"
	ok_button_text = "Apply"
	wrap_controls = true

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 8)
	margin.add_child(fields)

	var size_label := Label.new()
	size_label.text = "Font size"
	fields.add_child(size_label)

	_font_size = SpinBox.new()
	_font_size.min_value = 8
	_font_size.max_value = 72
	_font_size.step = 1
	_font_size.value = DEFAULT_FONT_SIZE
	_font_size.allow_greater = false
	_font_size.allow_lesser = false
	fields.add_child(_font_size)

	var families_label := Label.new()
	families_label.text = "Font families"
	fields.add_child(families_label)

	_font_families = LineEdit.new()
	_font_families.placeholder_text = "Menlo, Cascadia Mono, monospace"
	_font_families.tooltip_text = "Comma-separated system font names in fallback order."
	fields.add_child(_font_families)

	var explanation := Label.new()
	explanation.text = "Comma-separated fallback order. Saved per user for this project."
	explanation.modulate = Color(1, 1, 1, 0.65)
	fields.add_child(explanation)

	_bell_sound = CheckBox.new()
	_bell_sound.text = "Play sound for terminal bell"
	_bell_sound.tooltip_text = "Uses the operating system alert sound. The OS may disable it globally."
	_bell_sound.button_pressed = true
	fields.add_child(_bell_sound)

	_auto_close_exited = CheckBox.new()
	_auto_close_exited.text = "Close terminal tabs when their shell exits"
	_auto_close_exited.tooltip_text = "When enabled, running exit closes that terminal tab."
	_auto_close_exited.button_pressed = true
	fields.add_child(_auto_close_exited)


func set_values(
	font_size: int,
	font_families: PackedStringArray,
	bell_sound_enabled: bool,
	auto_close_exited: bool
) -> void:
	_font_size.value = clampi(font_size, 8, 72)
	_font_families.text = ", ".join(font_families)
	_bell_sound.button_pressed = bell_sound_enabled
	_auto_close_exited.button_pressed = auto_close_exited


func get_font_size() -> int:
	return roundi(_font_size.value)


func get_font_families() -> PackedStringArray:
	var result := PackedStringArray()
	for value in _font_families.text.split(","):
		var family := value.strip_edges()
		if not family.is_empty():
			result.append(family)
	if result.is_empty():
		result.append("monospace")
	return result


func is_bell_sound_enabled() -> bool:
	return _bell_sound.button_pressed


func is_auto_close_exited_enabled() -> bool:
	return _auto_close_exited.button_pressed
