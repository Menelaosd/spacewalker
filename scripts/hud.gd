extends CanvasLayer
## Exterior (spacewalk) HUD — cockpit-styled: custom vitals panel,
## gear rack, pulsing dock prompt, toast messages, screen FX.

const GEAR_PANEL := preload("res://scripts/gear_panel.gd")
const RADAR_PANEL := preload("res://scripts/radar_panel.gd")
const INVENTORY_SCREEN := preload("res://scripts/inventory_screen.gd")
const VITALS := preload("res://scripts/vitals_panel.gd")

var _msg_label: Label
var _msg_tween: Tween
var _dock_prompt: Label
var _flare_banner: Control
var _t := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make_theme()
	add_child(root)

	var vitals := VITALS.new()
	vitals.position = Vector2(18, 18)
	root.add_child(vitals)

	# holographic resource radar (top-right)
	var radar := RADAR_PANEL.new()
	root.add_child(radar)
	radar.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)

	# gear rack (bottom-right)
	var gear := GEAR_PANEL.new()
	root.add_child(gear)
	gear.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)

	# full inventory overlay (I / Tab)
	root.add_child(INVENTORY_SCREEN.new())

	# "enter ship" prompt — only visible while docked
	_dock_prompt = Label.new()
	_dock_prompt.text = "E    ENTER SHIP"
	_dock_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_prompt.add_theme_font_size_override("font_size", 15)
	_dock_prompt.modulate = Color(0.6, 0.9, 1.0, 0.0)
	root.add_child(_dock_prompt)
	_dock_prompt.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 120)

	var hint := Label.new()
	hint.text = "WASD thrust · SPACE stabilize · LMB mine · I inventory · Esc menu"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.4)
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)

	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.modulate.a = 0.0
	root.add_child(_msg_label)
	_msg_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 80)

	# flare warning banner, top-center — hazard stripes when it hits
	_flare_banner = Control.new()
	_flare_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flare_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare_banner.draw.connect(func():
		if GameState.flare_phase == "":
			return
		var vp := _flare_banner.get_viewport_rect().size
		var col := UITheme.ACCENT_WARM if GameState.flare_phase == "warn" else UITheme.DANGER
		var label := "⚠ HELIOS PURGE SWEEP — TAKE COVER" \
			if GameState.flare_phase == "warn" else "☢ SWEEP BURN — SHELTER BEHIND ROCK"
		UITheme.draw_warning_banner(_flare_banner,
			Rect2(vp.x * 0.5 - 260, 24, 520, 26), label,
			ThemeDB.fallback_font, col, 12))
	root.add_child(_flare_banner)

	GameState.notify.connect(_on_notify)


func _process(delta: float) -> void:
	_t += delta
	_flare_banner.queue_redraw()
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.in_dock:
		_dock_prompt.modulate.a = 0.75 + 0.25 * absf(sin(_t * 3.5))
	else:
		_dock_prompt.modulate.a = 0.0


func _on_notify(text: String) -> void:
	_msg_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_label.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(2.2)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.8)
