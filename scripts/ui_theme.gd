extends RefCounted
## One theme for every control the game does not style by hand: native dialogs,
## dropdown popups, tooltips, scrollbars, text fields, check boxes and progress bars.
## Without it those widgets fall back to Godot's grey editor look.

const INK = Color("e2e9dc")
const MUTED = Color("8da69d")
const MINT = Color("a5dfbc")
const GOLD = Color("e4ca8b")
const CORAL = Color("ef8a6f")
const PANEL = Color("152d2c")
const RAISED = Color("203c37")
const BORDER = Color("2f4b45")
const DEEP = Color("0d201e")

static func box(bg:Color, border:Color=BORDER, radius:int=8, margin:int=10, shadow:bool=false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 4)
	return sb

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	for type in ["Label", "Button", "OptionButton", "CheckBox", "CheckButton", "LineEdit", "PopupMenu", "TooltipLabel", "ItemList", "RichTextLabel"]:
		t.set_color("font_color", type, INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", DEEP)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("normal", "Button", box(RAISED))
	t.set_stylebox("hover", "Button", box(Color("33574b"), MINT))
	t.set_stylebox("pressed", "Button", box(Color("80b79b"), MINT))
	t.set_stylebox("disabled", "Button", box(Color("1c302c"), BORDER))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))
	t.set_color("font_hover_color", "OptionButton", Color.WHITE)
	t.set_color("font_focus_color", "OptionButton", Color.WHITE)
	t.set_color("font_pressed_color", "OptionButton", Color.WHITE)
	t.set_color("font_disabled_color", "OptionButton", MUTED)
	# Dropdown and context menus.
	t.set_stylebox("panel", "PopupMenu", box(Color("172f2d"), Color("3e6359"), 8, 6, true))
	t.set_stylebox("hover", "PopupMenu", box(Color("2f5348"), MINT, 6, 6))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color("62786f"))
	t.set_color("font_separator_color", "PopupMenu", MUTED)
	t.set_constant("v_separation", "PopupMenu", 8)
	# Tooltips.
	t.set_stylebox("panel", "TooltipPanel", box(Color("0f2422"), GOLD, 6, 10, true))
	t.set_color("font_color", "TooltipLabel", Color("f3eedb"))
	t.set_font_size("font_size", "TooltipLabel", 14)
	# Panels and native windows.
	t.set_stylebox("panel", "Panel", box(PANEL))
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("panel", "AcceptDialog", box(PANEL, BORDER, 0, 18))
	var frame := box(Color("102725"), Color("3e6359"), 10, 0, true)
	frame.expand_margin_top = 34
	frame.set_border_width_all(2)
	frame.border_width_top = 34
	frame.border_color = Color("1d3a35")
	t.set_stylebox("embedded_border", "Window", frame)
	t.set_stylebox("embedded_unfocused_border", "Window", frame)
	t.set_color("title_color", "Window", MINT)
	t.set_font_size("title_font_size", "Window", 16)
	t.set_constant("title_height", "Window", 34)
	# Scrollbars: slim, with a visible thumb on dark panels.
	for bar in ["VScrollBar", "HScrollBar"]:
		var track := box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 6, 0)
		var grab := box(Color("3f6a5d"), Color(0, 0, 0, 0), 6, 0)
		var grab_hi := box(Color("5c9480"), Color(0, 0, 0, 0), 6, 0)
		for sb in [track, grab, grab_hi]:
			sb.content_margin_left = 5; sb.content_margin_right = 5
			sb.content_margin_top = 5; sb.content_margin_bottom = 5
		t.set_stylebox("scroll", bar, track)
		t.set_stylebox("grabber", bar, grab)
		t.set_stylebox("grabber_highlight", bar, grab_hi)
		t.set_stylebox("grabber_pressed", bar, grab_hi)
	# Text entry.
	t.set_stylebox("normal", "LineEdit", box(DEEP, Color("3e6359"), 6, 10))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), GOLD, 6, 10))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color("3f6a5d"))
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	# Progress bars.
	t.set_stylebox("background", "ProgressBar", box(DEEP, BORDER, 6, 0))
	t.set_stylebox("fill", "ProgressBar", box(MINT, MINT, 6, 0))
	t.set_color("font_color", "ProgressBar", DEEP)
	# Check boxes keep their glyph but use readable colours.
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_hover_pressed_color", "CheckBox", Color.WHITE)
	return t
