extends Control

const Sim = preload("res://scripts/simulation.gd")
const Town = preload("res://scripts/town_view.gd")
const Board = preload("res://scripts/business_board.gd")
const Menu = preload("res://scripts/app_menu.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Settings = preload("res://scripts/game_settings.gd")
const Economy = preload("res://scripts/economy.gd")
const MapTools = preload("res://scripts/map_tools.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Icon = preload("res://scripts/ui_icon.gd")
const Meter = preload("res://scripts/ui_meter.gd")
const INK = Color("e2e9dc")
const MUTED = Color("8da69d")
const MINT = Color("a5dfbc")
const GOLD = Color("e4ca8b")
const CORAL = Color("ef8a6f")
const TOOL_NAMES = {"inspect":"Inspect","buy":"Buy land","demolish":"Bulldoze","datacenter":"Server hall","power":"Substation","cooling":"Cooling"}
var sim = Sim.new()
var stage: Control
var town
var inspector: Panel
var stats: Dictionary = {}
var tools_buttons: Dictionary = {}
var objective: Label
var objective_detail: Label
var guide_button:Button
var guided_control:Button
var guided_style:StyleBox
var ai_text: Label
var status_text: Label
var toast_label: Label
var toast_timer = 0.0
var clock_label: Label
var pause_button: Button
var speed_button: Button
var accumulator: float = 0
var autosave: float = 0
var paused = true
var speed = 1
var tool = "inspect"
var selected = 83
var dialog: ConfirmationDialog
var help_dialog: AcceptDialog
var pending: Callable
var save_path = Sim.SAVE_PATH
var announced_win = false
var sound: AudioStreamPlayer
var sound_enabled = true
var soundscape
var header: Panel
var mission: Panel
var companion: Panel
var toolbar: Panel
var fullscreen_button: Button
var windowed_size = Vector2i(1440, 900)
var windowed_position = Vector2i.ZERO
var windowed_mode = DisplayServer.WINDOW_MODE_WINDOWED
var fullscreen_transition = false
var district_card: Panel
var town_heading:Label
var business
var contract_button: Button
var notice_queue: Array = []
var announced_campaign=false
var menu
var saves
var settings
var session_started=false
var dirty=false
var leave_action:Callable
var last_thumbnail:Image
var thumbnail_timer=0.0
var qa=false
var map_tools
var overlay_choice:OptionButton
var overlay_legend:Label
var alert_button:Button
var council_button:Button
var operations_button:Button
var has_alert=false
var inspector_permit_error=""
var build_profile="balanced"
var meters: Dictionary = {}
var company_label: Label
var time_status: Label
var sound_button: Button
var view_cluster: Panel
var research_button: Button
var dock_end := 0.0
var inspector_open := true

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(request_window_close)
	qa="--qa" in OS.get_cmdline_user_args()
	if qa: save_path="user://qa-town.json"
	saves=SaveStore.new(qa)
	settings=Settings.new(qa)
	if not qa: settings.load_settings()
	session_started=qa and not "--front-menu" in OS.get_cmdline_user_args()
	theme=UiTheme.build()
	announced_win = sim.won
	announced_campaign=sim.campaign_won
	stage = Control.new()
	stage.size = Vector2(1440, 900)
	add_child(stage)
	build_interface()
	resized.connect(layout_stage)
	layout_stage()
	refresh_inspector()
	refresh_hud()
	sound = AudioStreamPlayer.new()
	add_child(sound)
	soundscape=load("res://scripts/soundscape.gd").new();soundscape.game=self;add_child(soundscape)
	apply_settings(false,false)
	if not qa and not settings.fullscreen: DisplayServer.window_set_size(settings.resolution)
	if not qa or "--front-menu" in OS.get_cmdline_user_args(): menu.open("title")
	if not qa and settings.fullscreen and not is_fullscreen(): toggle_fullscreen()
	get_tree().node_added.connect(wire_display_shortcut)
	for node in get_tree().root.find_children("*","Window",true,false): wire_display_shortcut(node)

func layout_stage() -> void:
	if stage == null: return
	# Scale controls for readability, then give the map every remaining pixel.
	var s = clampf(minf(size.x / 1440.0, size.y / 900.0), 0.6, 1.6)
	stage.scale = Vector2(s, s)
	stage.position = Vector2.ZERO
	stage.size = size / s
	var w = stage.size.x
	var h = stage.size.y
	if town == null: return
	# World first: thin top bar, a bottom dock, and one floating inspector.
	header.size.x = w - 24
	inspector.position = Vector2(w - 312, 76)
	fit_inspector()
	town.position = Vector2.ZERO
	town.size = stage.size
	town.play_area = Rect2(12, 70, w - 336, h - 70 - 88)
	town.update_camera()
	toolbar.position = Vector2(12, h - 78)
	toolbar.size.x = w - 24
	companion.position.x = dock_end + 10
	companion.size.x = toolbar.size.x - dock_end - 20
	ai_text.size.x = companion.size.x - 62
	view_cluster.position = Vector2(12, h - 128)
	overlay_legend.position = Vector2(view_cluster.size.x + 20, h - 124)
	overlay_legend.size.x = minf(760, w - 360 - overlay_legend.position.x)
	toast_label.position = Vector2(town.play_area.position.x + (town.play_area.size.x - toast_label.size.x) / 2, h - 170)
	if business!=null: business.fit()
	if menu!=null: menu.fit()
	if map_tools!=null: map_tools.fit()

func style(bg: Color, border: Color = Color("314b46"), radius: int = 10) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb

func panel(parent: Node, rect: Rect2, bg: Color = Color("152d2c"), shadow: bool = false) -> Panel:
	var p = Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb = style(bg)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.32)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p

func icon(parent: Node, glyph: String, rect: Rect2, color: Color = INK) -> Control:
	var i = Icon.new(glyph, color)
	i.position = rect.position
	i.size = rect.size
	parent.add_child(i)
	return i

## Dock button: glyph above a short caption, with the keyboard shortcut in the corner.
func icon_button(parent: Node, glyph: String, caption: String, key: String, rect: Rect2, action: Callable) -> Button:
	var b = button(parent, "", rect, action)
	b.tooltip_text = caption + ("  [" + key + "]" if key != "" else "")
	b.set_meta("glyph", icon(b, glyph, Rect2((rect.size.x - 24) / 2, 7, 24, 24)))
	var cap = label(b, caption, Rect2(2, rect.size.y - 22, rect.size.x - 4, 18), 11, INK)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.clip_text = true
	b.set_meta("caption", cap)
	var badge = label(b, key, Rect2(rect.size.x - 28, 3, 24, 13), 9, MUTED)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.set_meta("key", badge)
	return b

func set_caption(b: Button, caption: String, key: String = "") -> void:
	if b.has_meta("caption"):
		b.get_meta("caption").text = caption
		b.get_meta("key").text = key
		b.tooltip_text = caption + ("  [" + key + "]" if key != "" else "")
	else: b.text = caption

## Header gauge: icon, caption, large value and, for capacities, a thin meter.
func stat_chip(key: String, glyph: String, caption: String, x: float, w: float, with_meter: bool) -> void:
	icon(header, glyph, Rect2(x, 16, 22, 22), MINT)
	label(header, caption, Rect2(x + 30, 5, w - 30, 15), 10, MUTED)
	if key == "cash":
		stats.cash = button(header, "", Rect2(x + 24, 19, w - 26, 30), func(): business.open("finance"))
		stats.cash.alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats.cash.set_meta("base_font_size", 19)
		stats.cash.add_theme_font_size_override("font_size", roundi(19 * settings.ui_scale))
		for state in ["normal", "hover", "pressed", "focus"]:
			var flat = stats.cash.get_theme_stylebox(state).duplicate()
			flat.content_margin_left = 6
			if state == "normal": flat.bg_color = Color(0, 0, 0, 0); flat.border_color = Color(0, 0, 0, 0)
			stats.cash.add_theme_stylebox_override(state, flat)
	else:
		stats[key] = label(header, "—", Rect2(x + 30, 19, w - 30, 26), 19)
		stats[key].mouse_filter = Control.MOUSE_FILTER_PASS
	if with_meter:
		var m = Meter.new()
		m.position = Vector2(x + 30, 46)
		m.size = Vector2(w - 42, 4)
		header.add_child(m)
		meters[key] = m

func label(parent: Node, text: String, rect: Rect2, font_size: int = 16, color: Color = INK) -> Label:
	var l = Label.new()
	l.clip_text=true
	l.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text=text
	l.add_theme_font_size_override("font_size", roundi(font_size*settings.ui_scale))
	l.set_meta("base_font_size",font_size)
	l.add_theme_color_override("font_color", color)
	l.position = rect.position
	l.size = rect.size
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func paragraph(parent: Node, text: String, rect: Rect2, font_size: int = 15, color: Color = MUTED) -> Label:
	# Set wrapping before assigning text so its initial minimum width stays bounded.
	var l = Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", roundi(font_size*settings.ui_scale))
	l.set_meta("base_font_size",font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = rect.position
	l.size = rect.size
	l.text = text
	parent.add_child(l)
	return l

func button(parent: Node, text: String, rect: Rect2, action: Callable, accent: bool = false) -> Button:
	var b = Button.new()
	b.clip_text=true
	b.tooltip_text=text
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", roundi(14*settings.ui_scale))
	b.set_meta("base_font_size",14)
	b.add_theme_color_override("font_color", Color("152d2c") if accent else INK)
	b.add_theme_color_override("font_hover_color", Color("152d2c") if accent else Color.WHITE)
	b.add_theme_color_override("font_focus_color",Color("152d2c") if accent else Color.WHITE)
	b.add_theme_color_override("font_pressed_color",Color("152d2c"))
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_stylebox_override("normal", style(MINT if accent else Color("203c37")))
	b.add_theme_stylebox_override("hover", style(Color("b9edcf") if accent else Color("33574b"), MINT))
	b.add_theme_stylebox_override("pressed", style(Color("80b79b"), MINT))
	b.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), GOLD))
	b.add_theme_stylebox_override("disabled",style(Color("20332f"),Color("314b46")))
	if rect.size.x<=130:
		for state_name in ["normal","hover","pressed","focus","disabled"]:
			var compact=b.get_theme_stylebox(state_name).duplicate()
			compact.content_margin_left=6;compact.content_margin_right=6
			b.add_theme_stylebox_override(state_name,compact)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func build_interface() -> void:
	town = Town.new()
	town.sim = sim
	town.lot_selected.connect(on_selected)
	town.lot_activated.connect(apply_tool)
	town.cost_tag = tool_tag
	stage.add_child(town)
	# --- Top bar: where am I, what time is it, and how healthy is the campus. ---
	header = panel(stage, Rect2(12, 10, 1416, 56), Color("122826"), true)
	district_card = header
	town_heading = label(header, "LITTLEBROOK", Rect2(16, 7, 190, 24), 17, INK)
	company_label = label(header, "", Rect2(16, 31, 190, 18), 11, MUTED)
	clock_label = label(header, "", Rect2(212, 7, 112, 24), 16, INK)
	time_status = label(header, "", Rect2(212, 31, 112, 18), 11, GOLD)
	pause_button = button(header, "", Rect2(322, 10, 40, 36), toggle_pause)
	pause_button.set_meta("glyph", icon(pause_button, "play", Rect2(10, 8, 20, 20)))
	speed_button = button(header, "1×", Rect2(366, 10, 44, 36), cycle_speed)
	speed_button.tooltip_text = "Cycle speed 1× / 3× / 6×  [F4]"
	fullscreen_button = button(header, "", Rect2(414, 10, 40, 36), toggle_fullscreen)
	fullscreen_button.tooltip_text = "Fill the display / return to window  [F11]"
	icon(fullscreen_button, "fullscreen", Rect2(11, 9, 18, 18))
	var divider = ColorRect.new(); divider.color = Color("2f4b45")
	divider.position = Vector2(468, 10); divider.size = Vector2(1, 36); header.add_child(divider)
	stat_chip("cash", "cash", "CASH", 482, 150, false)
	stat_chip("profit", "profit", "NET / HOUR", 636, 118, false)
	stat_chip("compute", "compute", "COMPUTE IN USE", 758, 144, true)
	stat_chip("power", "power", "POWER  MW", 906, 136, true)
	stat_chip("cooling", "cooling", "COOLING  CU", 1046, 136, true)
	stat_chip("approval", "approval", "APPROVAL", 1186, 110, true)
	stat_chip("adoption", "research", "AI ADOPTION", 1300, 106, true)
	meters.approval.invert = true
	meters.adoption.fixed_color = Color("8fb8de")
	# --- Objective card and alerts float over the top-left of the world. ---
	mission = panel(stage, Rect2(12, 76, 420, 78), Color(0.09, 0.2, 0.18, 0.93), true)
	objective = label(mission, "", Rect2(14, 6, 330, 24), 15, MINT)
	objective_detail = paragraph(mission, "", Rect2(14, 31, 396, 42), 12, INK)
	objective_detail.max_lines_visible = 2
	objective_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective_detail.mouse_filter = Control.MOUSE_FILTER_PASS
	guide_button = button(mission, "Guide", Rect2(348, 6, 62, 26), func(): business.open("tutorial"))
	alert_button = button(stage, "", Rect2(12, 162, 420, 34), focus_alert)
	for state in ["normal", "hover"]:
		var warn = style(Color("4a3a1f") if state == "normal" else Color("5d4825"), GOLD)
		warn.content_margin_left = 38
		alert_button.add_theme_stylebox_override(state, warn)
	alert_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	alert_button.add_theme_color_override("font_color", Color("fbe7b5"))
	icon(alert_button, "alert", Rect2(10, 7, 20, 20), GOLD)
	alert_button.visible = false
	# --- Map view controls sit at the bottom-left of the world. ---
	view_cluster = panel(stage, Rect2(12, 772, 208, 42), Color(0.07, 0.16, 0.15, 0.94), true)
	icon(view_cluster, "layers", Rect2(8, 11, 20, 20), MINT)
	overlay_choice = OptionButton.new()
	overlay_choice.position = Vector2(32, 5); overlay_choice.size = Vector2(124, 32)
	overlay_choice.tooltip_text = "Map layer: electricity, cooling, noise, ownership or opinion"
	for layer_name in MapTools.LAYERS: overlay_choice.add_item(layer_name)
	overlay_choice.item_selected.connect(func(i): map_tools.set_layer(MapTools.LAYERS[i]))
	view_cluster.add_child(overlay_choice)
	var map_button = button(view_cluster, "", Rect2(162, 5, 40, 32), func(): map_tools.open())
	map_button.tooltip_text = "Town atlas: minimap, building list and camera bookmarks"
	icon(map_button, "map", Rect2(10, 6, 20, 20))
	overlay_legend = label(stage, "", Rect2(232, 776, 700, 34), 12, INK)
	overlay_legend.add_theme_stylebox_override("normal", style(Color(0.06, 0.13, 0.11, 0.94)))
	overlay_legend.visible = false
	# --- Floating property inspector. ---
	inspector = panel(stage, Rect2(1128, 76, 300, 632), Color("142b29"), true)
	# --- Bottom dock: build tools | management | system, then the AI news line. ---
	toolbar = panel(stage, Rect2(12, 822, 1416, 66), Color("102422"), true)
	var groups = [
		["inspect", "buy", "demolish"],
		["datacenter", "power", "cooling"],
		["contracts", "company", "operations", "council", "research"],
		["menu", "help", "sound"]]
	var captions = {"contracts":"Contracts", "company":"Company", "operations":"Operations", "council":"Council", "research":"Research", "menu":"Menu", "help":"Help", "sound":"Sound"}
	var bx = 8
	for group in groups:
		for key in group:
			var caption: String = TOOL_NAMES.get(key, captions.get(key, key))
			var wide = 58 if key in ["menu", "help", "sound"] else 68
			var b: Button
			match key:
				"contracts": b = icon_button(toolbar, key, caption, "C", Rect2(bx, 6, wide, 54), func(): business.open("offers")); contract_button = b
				"company": b = icon_button(toolbar, key, caption, "G", Rect2(bx, 6, wide, 54), func(): business.open("company"))
				"operations": b = icon_button(toolbar, key, caption, "", Rect2(bx, 6, wide, 54), func(): business.open("operations")); operations_button = b
				"council": b = icon_button(toolbar, key, caption, "", Rect2(bx, 6, wide, 54), func(): open_town()); council_button = b
				"research": b = icon_button(toolbar, key, caption, "", Rect2(bx, 6, wide, 54), func(): business.open("research")); research_button = b
				"menu": b = icon_button(toolbar, key, caption, "Esc", Rect2(bx, 6, wide, 54), func(): menu.open("pause"))
				"help": b = icon_button(toolbar, key, caption, "F1", Rect2(bx, 6, wide, 54), show_help)
				"sound": b = icon_button(toolbar, key, caption, "", Rect2(bx, 6, wide, 54), toggle_sound); sound_button = b
				_: b = icon_button(toolbar, key, caption, "", Rect2(bx, 6, wide, 54), func(): set_tool(key)); tools_buttons[key] = b
			bx += wide + 4
		bx += 10
		if group != groups[-1]:
			var sep = ColorRect.new(); sep.color = Color("2f4b45")
			sep.position = Vector2(bx - 12, 12); sep.size = Vector2(1, 42); toolbar.add_child(sep)
	dock_end = bx
	companion = panel(toolbar, Rect2(dock_end + 10, 6, 300, 54), Color("17302e"))
	var ai_button = button(companion, "AI", Rect2(8, 9, 40, 36), func(): business.open("research"), true)
	ai_button.tooltip_text = "Your AI companion · research journal"
	ai_text = paragraph(companion, "", Rect2(56, 4, 230, 46), 13, INK)
	ai_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ai_text.clip_text = true
	ai_text.max_lines_visible = 2
	ai_text.mouse_filter = Control.MOUSE_FILTER_PASS
	# --- News popup: a pill above the dock, like a ticker message. ---
	toast_label = label(stage, "", Rect2(300, 700, 760, 38), 15, Color("fbe7b5"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pill = style(Color(0.07, 0.15, 0.14, 0.96), GOLD, 18)
	pill.shadow_color = Color(0, 0, 0, 0.35); pill.shadow_size = 10; pill.shadow_offset = Vector2(0, 3)
	toast_label.add_theme_stylebox_override("normal", pill)
	dialog = ConfirmationDialog.new()
	dialog.title = "Hyperscale: Datacenter Tycoon"
	dialog.min_size = Vector2i(500, 170)
	dialog.dialog_autowrap = true
	dialog.ok_button_text = "Confirm"
	for b in [dialog.get_ok_button(), dialog.get_cancel_button()]:
		b.custom_minimum_size = Vector2(140, 40)
		b.add_theme_stylebox_override("normal", style(Color("203c37")))
		b.add_theme_stylebox_override("hover", style(Color("33574b"), MINT))
	dialog.get_ok_button().add_theme_stylebox_override("normal", style(MINT))
	dialog.get_ok_button().add_theme_color_override("font_color", Color("152d2c"))
	dialog.get_ok_button().add_theme_color_override("font_hover_color", Color("152d2c"))
	dialog.confirmed.connect(func():
		if pending.is_valid(): pending.call())
	add_child(dialog)
	help_dialog = AcceptDialog.new()
	help_dialog.title = "Welcome to Hyperscale: Datacenter Tycoon"
	help_dialog.min_size=Vector2i(760,580)
	help_dialog.size=Vector2i(760,580)
	add_child(help_dialog)
	var help_scroll=ScrollContainer.new()
	help_scroll.position=Vector2(18,14);help_scroll.size=Vector2(724,505)
	help_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	help_dialog.add_child(help_scroll)
	var help_content=VBoxContainer.new();help_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	help_content.add_theme_constant_override("separation",22);help_scroll.add_child(help_content)
	var help_sections=[
		["BUILD A CAMPUS","Pick a tool from the dock, then click the map: Buy land (B) buys the plot, Bulldoze (X) clears it, and Server hall / Substation / Cooling (1 / 2 / 3) build there. The tag beside the cursor shows the price, or why the action is not possible. Inspect (Q) or right-click only selects. Buy warehouse 04-06, clear it and build a server hall. Add power and cooling nearby. Utilities share capacity but reach only 4 / 7 / 12 blocks at tiers 1 / 2 / 3. Map layers show coverage, noise, ownership and opinion. Riverfront cooling gains 25% capacity. Remote road works cost extra; protected sites need a heritage hearing."],
		["GROW YOUR COMPANY","Contracts: C. Company: G. Projects pay on delivery; services pay hourly plus a bonus. Required delivery: 90% inference, 99% critical, 85% experimental. Review fees and deadline slack before signing. Use Active to prioritize scarce capacity. Two deliveries unlock tier 2; four unlock tier 3; eight unlock repeat commissions. Each town also has its own charter requirements. Click cash for finance, borrowing and hardware refits."],
		["KEEP THE LIGHTS ON","Operations shows forecasts, failures and maintenance. Batteries bridge startup; generators need fuel and a working hub. Mobile chillers can cover heat or cooling service. Preventive crews reduce wear. Forecasts and incidents can pause time automatically; change this in Settings."],
		["THE TOWN PUSHES BACK","Town council separates public approval from AI adoption. Homes, noise, traffic, resource strain and unreliable services create specific concerns. Warning → petition → demonstration → permit pause. At a pause, new halls and hall upgrades are restricted; utility upgrades, repairs, refits and remedies remain available. Reduce pressure below 12 to recover. Negotiate a 24h measurable promise, rehouse families, quiet or relocate equipment, restore parks, preserve heritage or fund infrastructure. Expedited permits last 24h and damage trust."],
		["FEED THE AI","Company or the AI button opens research. Reserve 0%, 10%, 25% or 50% of online compute for Engineer, Commercial or Visionary projects. Research gets capacity before customers; its review shows the delivery and cash-flow cost. Switching projects keeps progress. Completed projects release compute. Customer scout introduces SmilingFace and later local pilots; experimental research unlocks unusual commissions. Outreach creates demand you must actually serve."],
		["PEOPLE AND CUSTOMERS","Company contains staffing and nine fictional customer profiles. Technicians cost $7 per team/hour and dispatch paid repairs or service. Engineers cost $9 and shorten new visits/refits, to a minimum of one hour. Commercial teams cost $6 and improve newly signed project deadlines and fees. Hire up to three teams per role. Existing jobs and signed contract terms keep their rules. Delivery vans and workers represent actual dispatches."],
		["THREE TOWNS, YOUR PACE","Town charter explains the finale: Littlebrook needs eight deliveries; Sunsprawl adds sustained efficient operation with limited water; Oldbridge requires preservation, rehousing and trust. Completing a charter offers the next town or continued play. Local achievements belong to the saved company; sandbox does not award them. The nine-step Guide can be skipped or resumed. At 1x, an hour takes four seconds; 3x and 6x are available. Settings separate music and ambience and include reduced motion."],
		["SAVE AND NAVIGATE","The top bar shows cash, net cash per hour and capacity gauges; a gauge turns gold near its limit and red when demand exceeds supply. Click cash for finances. Space: pause / run. F4: speed. F5: quicksave. F9: load. F1: this guide. F11 or Alt+Enter: fullscreen. Escape closes a panel, exits fullscreen or opens the company menu. Home: whole town. Mouse wheel: zoom. Middle-drag: pan. Tab / Shift+Tab: keyboard focus; Enter selects. Map provides buildings and saved camera bookmarks. Core controls can be rebound in Settings. Autosaves rotate every 15 seconds. Save Game creates a named slot. Leaving unsaved work asks what to do; loaded towns begin paused."]]
	for section in help_sections:
		var heading=label(help_content,section[0],Rect2(0,0,680,30),19,MINT)
		heading.custom_minimum_size.y=32
		var copy=paragraph(help_content,section[1],Rect2(0,0,680,0),17,INK)
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL

	business=Board.new()
	business.game=self
	stage.add_child(business)
	map_tools=MapTools.new()
	map_tools.game=self
	stage.add_child(map_tools)
	menu=Menu.new()
	menu.game=self
	stage.add_child(menu)
	set_tool("inspect")

func set_tool(mode: String) -> void:
	tool = mode
	town.tool = mode
	for key in tools_buttons:
		var active = key == mode
		var sb = style(Color("2f5a4a") if active else Color("1a3431"), MINT if active else Color("2a4440"))
		if active: sb.set_border_width_all(2)
		tools_buttons[key].add_theme_stylebox_override("normal", sb)
		if tools_buttons[key].has_meta("glyph"): tools_buttons[key].get_meta("glyph").tint = MINT if active else INK
	refresh_inspector()

func on_selected(index: int) -> void:
	selected = index
	inspector_open = true
	inspector.visible = true
	Sim.Tutorial.mark(sim,"inspect")
	dirty=true
	if town.tool != tool:
		set_tool(town.tool)
	refresh_inspector()

func refresh_inspector() -> void:
	inspector_permit_error=Sim.Civic.expand_error(sim,sim.lots[maxi(0,selected)])
	if inspector == null: return
	for child in inspector.get_children():
		inspector.remove_child(child)
		child.queue_free()
	status_text = null
	if selected < 0: return
	var lot: Dictionary = sim.lots[selected]
	var building=sim.building_stats(lot)
	var names = {"grass": "Open land", "house": "Town home", "warehouse": "Old warehouse", "park": "Pocket park", "monument": "Founder's monument", "water": "River", "road": "Public road", "datacenter": "Server hall", "power": "Substation", "cooling": "Cooling plant"}
	label(inspector, "PROPERTY  /  %02d-%02d" % [lot.x + 1, lot.y + 1], Rect2(20, 17, 220, 22), 12, MUTED)
	var close = button(inspector, "", Rect2(258, 12, 28, 28), func(): inspector_open = false; inspector.visible = false)
	close.tooltip_text = "Close the inspector. Selecting a plot reopens it."
	icon(close, "close", Rect2(7, 7, 14, 14), MUTED)
	var kind_glyph = {"datacenter":"datacenter", "power":"power", "cooling":"cooling", "grass":"buy", "house":"approval", "park":"council", "monument":"council", "warehouse":"company", "road":"map", "water":"map"}
	var badge = panel(inspector, Rect2(20, 47, 40, 40), Color("21403a"))
	icon(badge, kind_glyph.get(lot.kind, "inspect"), Rect2(9, 9, 22, 22), MINT if lot.owned else GOLD)
	label(inspector, names[lot.kind], Rect2(70, 49, 218, 36), 24)
	label(inspector, "YOUR PROPERTY" if lot.owned else "TOWN PROPERTY", Rect2(20, 94, 260, 24), 12, MINT if lot.owned else GOLD)
	if Sim.BUILDINGS.has(lot.kind):
		var condition = float(lot.get("condition", 100))
		label(inspector, "CONDITION  %d%%" % roundi(condition), Rect2(150, 90, 130, 18), 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var wear = Meter.new()
		wear.invert = true
		wear.position = Vector2(150, 110); wear.size = Vector2(130, 4)
		wear.set_values(condition, 100)
		inspector.add_child(wear)
	var descriptions = {
		"grass": "Room for your next big idea. One building fits on each plot.",
		"house": "An occupied town property. Relocation and neighborhood disruption carry an approval cost.",
		"warehouse": "An empty warehouse by the main road. The perfect place for your first campus.",
		"park": "A small green refuge. Neighborhood sensitivity determines the approval cost of removing it.",
		"monument": "The town's founder. Apparently not replaceable by a chatbot. Demolition costs 25 approval.",
		"water": "Protected public waterway. Riverfront cooling plants gain 25% capacity.",
		"road": "Public access is protected. Build on the surrounding plots.",
		"datacenter": "100 compute capacity\nNeeds 40 MW + 40 cooling\nUpkeep: $38 per hour",
		"power": "Supplies 120 MW to your network.\nUpkeep: $8 per hour\nEnough for two halls + a cooler.",
		"cooling": "Supplies 120 cooling at full power.\nNeeds 20 MW\nUpkeep: $12 per hour"
	}
	if lot.kind=="grass" and lot.owned:
		var preview_lot=lot.duplicate();preview_lot.kind="datacenter";preview_lot.level=1;preview_lot.hardware=build_profile
		var b=sim.building_stats(preview_lot)
		descriptions.grass="%s\n%d compute · %.0f MW · %.0f CU\nEquipment %s/h + energy" % [Economy.HARDWARE[build_profile].name,b.capacity,b.power,b.cooling,money(b.upkeep)]
	if not building.is_empty():
		var output="%d compute · %d MW / %d CU" % [building.capacity,building.power,building.cooling] if lot.kind=="datacenter" else ("Supplies %d MW" % building.capacity if lot.kind=="power" else "%d CU · %d MW required" % [building.capacity,building.power])
		descriptions[lot.kind]="Tier %d · %s\n%s\nEquipment + staff: %s/h" % [lot.level,building.name,output,money(building.upkeep)]
	var area=Sim.Geography.DISTRICTS[Sim.Geography.district(int(lot.x),int(lot.y))]
	label(inspector,area.name,Rect2(20,117,260,22),12,GOLD)
	paragraph(inspector, descriptions[lot.kind], Rect2(20, 145, 260, 83), 14, INK)
	if lot.kind in ["road","water"]:
		paragraph(inspector, "Select a property beside the road to begin.", Rect2(20, 260, 260, 70))
	elif not lot.owned:
		label(inspector, "ACQUISITION PRICE", Rect2(20, 254, 260, 20), 11, MUTED)
		label(inspector, money(lot.price), Rect2(20, 279, 260, 40), 32, INK)
		button(inspector, "Buy property  ·  " + money(lot.price), Rect2(20, 338, 260, 47), buy_selected, true)
		paragraph(inspector,site_text(selected),Rect2(20,397,260,110),13)
	elif lot.kind == "grass":
		label(inspector, "HARDWARE FOR NEW SERVER HALL", Rect2(20, 233, 260, 22), 12, MINT)
		var choices=Economy.HARDWARE.keys()
		var choice=OptionButton.new()
		choice.position=Vector2(20,261);choice.size=Vector2(260,32)
		for profile in choices:
			choice.add_item(Economy.HARDWARE[profile].name)
			choice.set_item_disabled(choice.item_count-1,not sim.hardware_unlocked(profile))
			choice.get_popup().set_item_tooltip(choice.item_count-1,Economy.HARDWARE[profile].brief)
		choice.selected=choices.find(build_profile)
		choice.item_selected.connect(func(i):build_profile=choices[i];town.build_profile=build_profile;dirty=true;refresh_inspector();call_deferred("focus_hall_button"))
		inspector.add_child(choice)
		var row = 303
		for kind in ["datacenter", "power", "cooling"]:
			var b: Dictionary = Sim.BUILDINGS[kind]
			var build_button=button(inspector, b.name + "  ·  " + money(sim.construction_cost(selected,kind,build_profile)), Rect2(20, row, 260, 42), func(): build_selected(kind), tool == kind or (tool in ["inspect", "buy", "demolish"] and kind == "datacenter"))
			if kind=="datacenter" and not Sim.Civic.expand_error(sim,lot).is_empty():
				build_button.disabled=true;build_button.tooltip_text=Sim.Civic.expand_error(sim,lot)
			row += 50
		paragraph(inspector,site_text(selected),Rect2(20,457,260,79),12)
	else:
		if Sim.BUILDINGS.has(lot.kind):
			status_text = paragraph(inspector, "", Rect2(20, 239, 260, 62), 14, MINT)
			var level=int(lot.level)
			if level<3:
				var next_lot=lot.duplicate();next_lot.level=level+1
				var next:Dictionary=sim.building_stats(next_lot)
				var unlocked=level<sim.tech_level()
				var caption="Upgrade T%d  ·  %s" % [level+1,money(next.cost)] if unlocked else "Locked · deliver %d customers" % (2 if level==1 else 4)
				var ub=button(inspector,caption,Rect2(20,310,260,42),func():upgrade_selected(),unlocked)
				ub.disabled=not unlocked or (lot.kind=="datacenter" and not Sim.Civic.expand_error(sim,lot).is_empty())
				if lot.kind=="datacenter" and not Sim.Civic.expand_error(sim,lot).is_empty(): ub.tooltip_text=Sim.Civic.expand_error(sim,lot)
				var preview="Next: %d compute · %d MW / %d cooling\nUpkeep %s/h" % [next.capacity,next.power,next.cooling,money(next.upkeep)] if lot.kind=="datacenter" else "Next: %d capacity · %d MW used\nUpkeep %s/h" % [next.capacity,next.power,money(next.upkeep)]
				paragraph(inspector,preview,Rect2(20,361,260,47),12)
			else: label(inspector,"MAXIMUM TIER · FULLY UPGRADED",Rect2(20,316,260,27),12,GOLD)
			button(inspector,"Demolish  ·  "+money(sim.demolition_cost(lot.kind)),Rect2(20,430,260,39),demolish_selected)
			if lot.kind=="datacenter": button(inspector,"Hardware / finances",Rect2(20,478,260,34),func():business.open("hardware"))
		else:
			paragraph(inspector,site_text(selected),Rect2(20,240,260,128),13)
			if lot.get("protected",false) and not lot.get("permit",false) and not lot.get("preserved",false):
				button(inspector,"Heritage hearing · $4,000",Rect2(20,325,260,40),func():ask("Redevelop protected land?","Hearing and relocation plan: $4,000. Demolition and approval costs still apply.",func():complete_action(sim.redevelopment_permit(selected),"Heritage relocation approved.")))
			var clear_button=button(inspector, "Preserved permanently" if lot.get("preserved",false) else "Demolish  ·  " + money(sim.demolition_cost(lot.kind)), Rect2(20, 378, 260, 47), demolish_selected, tool == "demolish" or lot.kind == "warehouse")
			clear_button.disabled=lot.get("preserved",false)
			if clear_button.disabled: clear_button.tooltip_text="A permanent conservation covenant protects this site."
			paragraph(inspector, "Conservation protects this site permanently. Its park or landmark remains part of the town." if lot.get("preserved",false) else "Clearing costs %s and %d approval. Construction is not refunded." % [money(sim.demolition_cost(lot.kind)),Sim.Geography.demolition_impact(lot)], Rect2(20, 444, 260, 67))
	button(inspector,"Operations / condition" if Sim.BUILDINGS.has(lot.kind) else "C  Customer contracts",Rect2(20,543,260,39),func():business.open("operations" if Sim.BUILDINGS.has(lot.kind) else "offers"))
	fit_inspector()
	refresh_status()

func fit_inspector() -> void:
	var bottom = 0.0
	for child in inspector.get_children():
		if child is Control and child.visible: bottom = maxf(bottom, child.position.y + child.size.y)
	inspector.size.y = minf(bottom + 18, stage.size.y - 76 - 92)

## Clicking the map with a tool performs that tool's action, as in classic tycoon
## games. Inspect only selects. Destructive actions still ask for confirmation.
func apply_tool(index: int) -> void:
	if index < 0 or index >= sim.lots.size() or tool == "inspect": return
	var lot: Dictionary = sim.lots[index]
	match tool:
		"buy":
			if lot.kind in ["road", "water"] or lot.owned: return
			buy_selected()
		"demolish":
			if lot.kind in ["road", "water", "grass"]: return
			if not lot.owned: toast("Buy this property before clearing it."); return
			demolish_selected()
		"datacenter", "power", "cooling":
			if lot.kind in ["road", "water"]: return
			if not lot.owned: toast("Buy this plot first (" + settings.key_label("buy") + "), then build."); return
			if lot.kind != "grass": return
			build_selected(tool)

## Short cursor label for the hovered plot: what the active tool would cost, or why not.
func tool_tag(index: int) -> Dictionary:
	var lot: Dictionary = sim.lots[index]
	if lot.kind in ["road", "water"]: return {"text": "Public land", "tone": "bad"}
	match tool:
		"buy":
			if lot.owned: return {"text": "Owned", "tone": "warn"}
			return {"text": "Buy " + money(lot.price), "tone": "ok" if sim.cash >= lot.price else "bad"}
		"demolish":
			if not lot.owned: return {"text": "Buy first · " + money(lot.price), "tone": "warn"}
			if lot.kind == "grass": return {}
			if lot.get("preserved", false): return {"text": "Preserved", "tone": "bad"}
			if lot.get("protected", false) and not lot.get("permit", false): return {"text": "Heritage hearing needed", "tone": "bad"}
			var cost = sim.demolition_cost(lot.kind)
			var impact = Sim.Geography.demolition_impact(lot)
			return {"text": "Clear " + money(cost) + (" · -%d approval" % impact if impact > 0 else ""), "tone": ("warn" if impact > 0 else "ok") if sim.cash >= cost else "bad"}
		"datacenter", "power", "cooling":
			if not lot.owned: return {"text": "Buy first · " + money(lot.price), "tone": "warn"}
			if lot.kind != "grass": return {"text": "Clear the site first", "tone": "bad"}
			var p = sim.site_preview(index, tool, build_profile)
			if not p.permit_error.is_empty(): return {"text": "Hall permits paused", "tone": "bad"}
			var cost = sim.construction_cost(index, tool, build_profile)
			if sim.cash < cost: return {"text": "Need " + money(cost), "tone": "bad"}
			var missing = []
			if tool != "power" and not p.power: missing.append("power")
			if tool == "datacenter" and not p.cooling: missing.append("cooling")
			if missing.is_empty(): return {"text": "Build " + money(cost), "tone": "ok"}
			return {"text": "Build " + money(cost) + " · no " + " / ".join(missing) + " in reach", "tone": "warn"}
	return {}

func upgrade_selected() -> void:
	complete_action(sim.upgrade(selected),"Building upgraded. Review the campus utility balance.")

func buy_selected() -> void:
	var result = sim.buy(selected)
	complete_action(result, "Property acquired. The town calls this progress.")

func build_selected(kind: String) -> void:
	var result = sim.build(selected, kind,build_profile if kind=="datacenter" else "balanced")
	complete_action(result, Sim.BUILDINGS[kind].name + " constructed. Check your power and cooling.")

func demolish_selected() -> void:
	var index = selected
	var lot: Dictionary = sim.lots[index]
	var impact = Sim.Geography.demolition_impact(lot)
	if impact > 0 or Sim.BUILDINGS.has(lot.kind):
		ask("Demolish this property?", "Cost: %s. Public approval: -%d.\nThe building will be removed; you keep the land." % [money(sim.demolition_cost(lot.kind)), impact], func(): do_demolish(index))
	else: do_demolish(index)

func do_demolish(index: int) -> void:
	var result = sim.demolish(index)
	if result == "": town.dust(index)
	complete_action(result, "Site cleared. Your future has excellent floor space.")

func complete_action(error: String, success: String) -> void:
	toast(success if error == "" else error)
	if error == "":
		Sim.Tutorial.capture(sim)
		Sim.Achievements.capture(sim)
		dirty=true
		chime()
	refresh_inspector()
	refresh_hud()
	if business!=null and business.visible: business.refresh()

func ask(title_text: String, text: String, action: Callable) -> void:
	pending = action
	dialog.title = title_text
	dialog.dialog_text = text
	dialog.popup_centered()

func money(amount: float) -> String:
	var n = str(absi(roundi(amount)))
	var result = ""
	for i in range(n.length()):
		if i > 0 and (n.length() - i) % 3 == 0: result += ","
		result += n[i]
	return ("-$" if amount < 0 else "$") + result

func money_detail(amount:float) -> String:
	var cents=roundi(absf(amount)*100)
	return ("-" if amount<0 else "")+money(cents/100)+".%02d" % (cents%100)

func refresh_status() -> void:
	if status_text == null or selected < 0: return
	var m = sim.metrics()
	var kind: String = sim.lots[selected].kind
	if selected in m.servicing:
		status_text.text="SERVICE · %dh left\nCondition will be restored to 100%%." % (sim.lots[selected].service_until-sim.hour)
		return
	if selected in m.failures:
		status_text.text="FAILED · Repair required\nOpen Operations to dispatch a crew."
		return
	if kind == "datacenter":
		if selected in m.servicing: status_text.text="SERVICE · %dh left\nCondition will be restored to 100%%." % (sim.lots[selected].service_until-sim.hour)
		elif selected in m.failures: status_text.text="FAILED · Repair required\nOpen Operations to dispatch a crew."
		elif selected in m.refitting: status_text.text="REFITTING · %dh left\nContracts keep their deadlines." % (sim.lots[selected].refit_until-sim.hour)
		elif selected in m.disconnected: status_text.text = "OFFLINE · Outside utility reach\nUse Power / Cooling map layers."
		elif m.power == 0: status_text.text = "OFFLINE · No electricity\nBuild a substation on another plot."
		elif m.cooling == 0: status_text.text = "OFFLINE · No cooling\nBuild a cooling plant on another plot."
		elif m.efficiency < 1: status_text.text = "THROTTLED · %d%% output\nAdd power or cooling capacity." % roundi(m.efficiency * 100)
		else: status_text.text = "ONLINE · 100% capacity\nReady for AI customer workloads."
	elif kind == "power": status_text.text = "CONNECTED\n%d / %d MW network demand" % [m.power_need, m.power]
	elif kind == "cooling": status_text.text = "COOLING NETWORK\n%d / %d CU demand / available" % [m.cooling_need, m.cooling]

func refresh_hud() -> void:
	if town_heading!=null: town_heading.text=Sim.Scenarios.info(sim.scenario_id).name.to_upper()
	if inspector_permit_error!=Sim.Civic.expand_error(sim,sim.lots[maxi(0,selected)]): refresh_inspector()
	var m = sim.metrics()
	var offline:Array=m.disconnected
	var op_status=sim.operations_status()
	has_alert=not offline.is_empty() or not op_status.is_empty()
	alert_button.visible=has_alert
	if not op_status.is_empty(): alert_button.text=op_status
	elif not offline.is_empty(): alert_button.text="%d building outside utility reach · Locate" % offline.size()
	alert_button.tooltip_text=alert_button.text+" (click to respond)"
	stats.cash.text = money(sim.cash)
	if absf(sim.cash)>=1000000: stats.cash.text=("-$" if sim.cash<0 else "$")+"%.2fm" % (absf(sim.cash)/1000000.0)
	stats.cash.add_theme_color_override("font_color", CORAL if sim.cash < 0 else INK)
	stats.cash.tooltip_text="Open finances, loans and hardware · Cash "+money(sim.cash)+(" · Debt "+money(sim.finance.debt) if sim.finance.debt>0 else "")
	stats.profit.text = ("+" if m.profit >= 0 else "") + money(m.profit)
	stats.profit.add_theme_color_override("font_color", MINT if m.profit >= 0 else CORAL)
	stats.profit.tooltip_text="Net cash flow per simulation hour, after upkeep, wages, electricity and interest"
	var used=m.sold+m.research_compute
	stats.compute.text = "%d / %d" % [used,m.compute]
	stats.compute.tooltip_text="Paying work %.1f · AI research %.1f · Online %.1f · Unused compute earns nothing" % [m.sold,m.research_compute,m.compute]
	meters.compute.set_values(used,m.compute)
	meters.compute.fixed_color=Color("7fd3a4") if m.compute>0 else Color(0,0,0,0)
	stats.power.text = "%d / %d" % [m.power_need, m.power]
	stats.cooling.text = "%d / %d" % [m.cooling_need, m.cooling]
	meters.power.set_values(m.power_need,m.power)
	meters.cooling.set_values(m.cooling_need,m.cooling)
	stats.power.add_theme_color_override("font_color", CORAL if m.power_need > m.power else INK)
	stats.cooling.add_theme_color_override("font_color", CORAL if m.cooling_need > m.cooling else INK)
	stats.power.tooltip_text="Electricity demand / supply. Short supply throttles every hall."
	stats.cooling.tooltip_text="Cooling demand / supply. Short supply throttles every hall."
	stats.approval.text = "%d%%" % sim.approval
	meters.approval.set_values(sim.approval,100)
	stats.approval.add_theme_color_override("font_color", CORAL if sim.approval < 40 else INK)
	stats.approval.tooltip_text="Public approval. Open Council for causes, district stress and remedies."
	var adoption=roundi(Sim.Civic.adoption(sim))
	stats.adoption.text = "%d%%" % adoption
	meters.adoption.set_values(adoption,100)
	stats.adoption.tooltip_text="Average AI adoption. Raises the town's spot-market demand; independent of approval."
	var civic_count=0
	for ward in sim.civic.wards.values():
		if ward.stage>=2: civic_count+=1
	set_caption(council_button,("Council (%d!)" % civic_count) if civic_count>0 else "Council")
	council_button.get_meta("glyph").tint=GOLD if civic_count>0 else INK
	clock_label.text = "Day %d  %02d:00" % [sim.hour / 24 + 1, sim.hour % 24]
	company_label.text = sim.company_name
	update_time_controls()
	clock_label.tooltip_text="Day %d, %02d:00 · %s · 1× = 4 seconds/hour" % [sim.hour/24+1,sim.hour%24,"Paused" if paused else "Running at %d×" % speed]
	if not sim.bought:
		objective.text = "01 / 04     A foothold in "+Sim.Scenarios.info(sim.scenario_id).name
		objective_detail.text = "Buy the highlighted old warehouse for $1,200."
		ai_text.text = "“An abandoned warehouse. Finally, a building with realistic expectations.”"
	elif not sim.cleared and not sim.built:
		objective.text = "02 / 04     Make some room"
		objective_detail.text = "Demolish an owned building. The old warehouse costs $250 to clear."
		ai_text.text = "“The warehouse contains no GPUs. I recommend an architectural correction.”"
	elif not sim.built:
		objective.text = "03 / 04     Your first server hall"
		objective_detail.text = "Select cleared land and build a server hall for $4,800."
		ai_text.text = "“Your town had history. Now it has capacity. Well, soon.”"
	elif not sim.won:
		objective.text = "04 / 04     Feed the AI     ·     %s / $1,200 earned" % money(minf(sim.earned, 1200))
		objective_detail.text = "Run time to earn revenue from your connected campus." if m.compute>0 else ("Work is underway. Let the equipment timer finish; customer deadlines continue." if not m.servicing.is_empty() or not m.refitting.is_empty() else "Open Operations to inspect shortages, failed equipment or missing utility links.")
		ai_text.text = "“My needs are modest: electricity, cooling, and eventually the entire town.”"
	else:
		var count=sim.campaign_count()
		objective.text=Sim.Scenarios.info(sim.scenario_id).name.to_upper()+" COMPLETE · Continue playing" if sim.campaign_won else "AI PROVIDER · %d / 8 customers delivered" % count
		objective_detail.text="New Open Exchange commissions are available. C opens contracts." if sim.campaign_won else ("Deliver 2 customers to unlock GPU clusters. Press C for offers." if count<2 else ("Select your buildings to upgrade. Next unlock: 4 deliveries." if count<4 else "Grow your capacity for frontier AI customers. C opens offers."))
		ai_text.text="“You have built an empire. My next request is only slightly larger than the planet.”" if sim.campaign_won else "“Customers pay for compute. I pay you in increasingly ambitious suggestions.”"
	if not sim.research.comments.is_empty():
		ai_text.text="AI / "+Sim.Research.personality(sim)+" · "+sim.research.comments[0].message.left(125)+("…" if sim.research.comments[0].message.length()>125 else "")
		ai_text.tooltip_text=sim.research.comments[0].message
	if sim.cash < 2000 and not sim.rescued:
		ai_text.text = "Emergency funding available: press R for a one-time $8,000 grant."
	update_guide()
	refresh_status()
	set_caption(contract_button,"Contracts %d/3" % sim.active.size() if not sim.active.is_empty() else "Contracts",settings.key_label("contracts"))

func _process(delta: float) -> void:
	if stage == null: return
	var in_menu=menu!=null and menu.visible
	town.activity_speed = 0.0 if paused or in_menu or dialog.visible or help_dialog.visible else float(speed)
	if in_menu and menu.mode=="title" and not settings.reduced_motion: town.activity_speed=0.25
	if settings.reduced_motion: town.activity_speed=0
	if session_started and not in_menu: sim.play_seconds+=delta
	toast_timer -= delta
	toast_label.visible = toast_timer > 0
	var title_only=in_menu and menu.mode=="title" and not session_started
	for child in stage.get_children():
		if child!=town and child!=menu and child!=business and child!=map_tools and child!=alert_button and child is CanvasItem:
			child.visible=not title_only
	alert_button.visible=not title_only and has_alert
	toast_label.visible=not title_only and toast_timer>0
	inspector.visible=not title_only and inspector_open
	overlay_legend.visible=not title_only and map_tools.layer!="Town view"
	if session_started and not in_menu: handle_operation_alerts()
	if session_started and not paused and not in_menu and not dialog.visible and not help_dialog.visible:
		accumulator += minf(delta, 0.25) * speed
		while accumulator >= 4:
			accumulator -= 4
			sim.tick()
			handle_operation_alerts()
			dirty=true
			refresh_hud()
			if sim.won and not announced_win:
				announced_win = true
				toast("CAMPUS ESTABLISHED! You earned your first $1,200. Keep expanding.")
				chime()
			if sim.campaign_won and not announced_campaign:
				announced_campaign=true
				if not paused: toggle_pause()
				business.open("company")
				toast(Sim.Scenarios.info(sim.scenario_id).name.to_upper()+" COMPLETE! Open the Town charter for distinctions and the next town.")
				chime()
			if not sim.notices.is_empty():
				for message in sim.notices: notice_queue.append(message)
				sim.notices.clear()
				refresh_inspector()
			if paused:
				accumulator=0
				break
	town.work_fraction=0.5 if settings.reduced_motion else accumulator/4.0
	if toast_timer<=0 and not notice_queue.is_empty():
		toast(notice_queue.pop_front())
		chime()
	if session_started and not in_menu and not dialog.visible and not help_dialog.visible:
		autosave += delta
	if autosave >= 15:
		autosave = 0
		if saves.autosave(sim,get_view_state(),last_thumbnail): dirty=false
		else: toast(saves.last_error)
	thumbnail_timer+=delta
	if thumbnail_timer>=5 and not in_menu and not business.visible:
		thumbnail_timer=0
		capture_thumbnail()

func toast(text: String) -> void:
	toast_label.text = text
	toast_label.tooltip_text = text
	var font = toast_label.get_theme_font("font")
	var font_size = toast_label.get_theme_font_size("font_size")
	var width = clampf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 52, 260, town.play_area.size.x - 40)
	toast_label.size = Vector2(width, 38)
	toast_label.position.x = town.play_area.position.x + (town.play_area.size.x - width) / 2
	toast_timer = 6
	toast_label.visible = true

func toggle_pause() -> void:
	paused = not paused
	update_time_controls()

func cycle_speed() -> void:
	speed = 3 if speed == 1 else (6 if speed == 3 else 1)
	update_time_controls()

func update_time_controls() -> void:
	if pause_button == null: return
	pause_button.get_meta("glyph").glyph = "play" if paused else "pause"
	pause_button.tooltip_text = ("Run time" if paused else "Pause time") + "  [Space]"
	var pressed = style(Color("6b5a2c") if paused else Color("1a3431"), GOLD if paused else Color("2a4440"))
	pause_button.add_theme_stylebox_override("normal", pressed)
	speed_button.text = str(speed) + "×"
	if time_status != null:
		time_status.text = "PAUSED" if paused else "RUNNING  %d×" % speed
		time_status.add_theme_color_override("font_color", GOLD if paused else MINT)

func manual_save() -> void:
	menu.open("save")

func quicksave() -> void:
	if save_to(saves.directory+"/quick.json",sim.company_name+" · quicksave"): toast("Quicksave complete.")
	else: toast(saves.last_error)

func save_to(path:String,title:String) -> bool:
	if not saves.save_slot(sim,path,title,get_view_state(),last_thumbnail): return false
	dirty=false
	return true

func save_campaign() -> bool:
	if not saves.campaign_save(sim,get_view_state(),last_thumbnail): return false
	dirty=false
	return true

func get_view_state() -> Dictionary:
	return {"zoom":town.zoom,"pan_x":town.pan.x,"pan_y":town.pan.y,"selected":selected,"overlay":map_tools.layer,"bookmarks":map_tools.bookmarks,"hardware":build_profile}

func restore_view() -> void:
	town.zoom=clampf(float(sim.view_state.get("zoom",1)),0.65,2.4)
	town.pan=Vector2(sim.view_state.get("pan_x",0),sim.view_state.get("pan_y",0))
	selected=int(sim.view_state.get("selected",83))
	town.selected=selected
	build_profile=sim.view_state.get("hardware","balanced")
	if not sim.hardware_unlocked(build_profile): build_profile="balanced"
	town.build_profile=build_profile
	map_tools.bookmarks=sim.view_state.get("bookmarks",[]).duplicate(true)
	map_tools.set_layer(sim.view_state.get("overlay","Town view"))
	town.update_camera()
	town.reset_residents()
	town.invalidate()

func capture_thumbnail() -> void:
	if DisplayServer.get_name()=="headless": return
	var tex=get_viewport().get_texture()
	if tex!=null: last_thumbnail=tex.get_image()

func request_leave(action:Callable) -> void:
	if session_started and dirty:
		leave_action=action
		menu.open("unsaved")
	else: action.call()

func run_leave_action() -> void:
	var action=leave_action
	leave_action=Callable()
	if action.is_valid(): action.call()

func return_to_title() -> void:
	session_started=false
	paused=true
	update_time_controls()
	business.visible=false
	menu.open("title")

func start_company(company:String,scenario:String,challenge:String,guide:bool=true) -> void:
	menu.loading(10,"Preparing "+Sim.Scenarios.info(scenario).name+"…")
	await get_tree().process_frame
	sim.new_game(company,scenario,challenge)
	sim.tutorial.enabled=guide
	if scenario=="sandbox":
		sim.cash=1000000
		sim.finance=Economy.new_finance(sim.cash,sim.hour)
	menu.loading(55,"Establishing properties and utilities…")
	await get_tree().process_frame
	town.center_view()
	build_profile="balanced";town.build_profile=build_profile
	map_tools.bookmarks.clear()
	map_tools.set_layer("Town view")
	town.reset_residents()
	town.invalidate()
	selected=83
	town.selected=83
	accumulator=0
	announced_win=false
	announced_campaign=false
	notice_queue.clear()
	paused=true
	update_time_controls()
	session_started=true
	dirty=true
	business.visible=false
	refresh_inspector()
	refresh_hud()
	menu.loading(100,"Ready. Your town begins paused.")
	await get_tree().process_frame
	menu.visible=false
	await get_tree().process_frame
	capture_thumbnail()
	if not save_campaign(): toast(saves.last_error)
	else: toast("Welcome, "+sim.company_name+". Buy land to establish your first campus.")

func load_town(path:String,recover:bool=false) -> void:
	if path.is_empty(): menu.feedback.text="Choose a saved town first.";return
	menu.loading(15,"Reading saved company…")
	await get_tree().process_frame
	if not saves.load_slot(sim,path,recover):
		menu.open("load")
		menu.feedback.text=saves.last_error
		return
	menu.loading(65,"Restoring contracts, equipment and town state…")
	await get_tree().process_frame
	restore_view()
	session_started=true
	dirty=false
	paused=true
	update_time_controls()
	accumulator=0
	announced_win=sim.won
	announced_campaign=sim.campaign_won
	notice_queue.clear()
	business.visible=false
	refresh_inspector()
	refresh_hud()
	menu.loading(100,"Town restored. Review it before running time.")
	await get_tree().process_frame
	menu.visible=false
	await get_tree().process_frame
	capture_thumbnail()
	toast("Backup recovered. Save to a new slot when ready." if recover else "Town loaded. Simulation paused.")
	if recover: dirty=true

func load_saved() -> void:
	menu.open("load")

func restart() -> void:
	menu.open("new")

func show_help() -> void:
	help_dialog.popup_centered()

func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	settings.sound=sound_enabled
	settings.save_settings()
	update_sound_button()

func update_sound_button() -> void:
	if sound_button == null: return
	sound_button.get_meta("glyph").glyph = "sound" if sound_enabled else "sound_off"
	set_caption(sound_button, "Sound" if sound_enabled else "Muted")

func chime() -> void:
	if not sound_enabled or sound == null: return
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data = PackedByteArray()
	data.resize(4410)
	for i in range(2205):
		var value = sin(i * TAU * 660 / 22050.0) * (1.0 - i / 2205.0) * 1800
		data.encode_s16(i * 2, int(value))
	wav.data = data
	sound.stream = wav
	sound.play()

func _input(event: InputEvent) -> void:
	if handle_display_shortcut(event): get_viewport().set_input_as_handled()
	elif menu!=null and menu.visible and event is InputEventKey and menu.capture_key(event): get_viewport().set_input_as_handled()

func handle_display_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	if event.keycode==KEY_F11 or event.physical_keycode==KEY_F11 or (event.alt_pressed and event.keycode==KEY_ENTER):
		toggle_fullscreen()
		return true
	return false

func wire_display_shortcut(node:Node) -> void:
	# Each native popup has its own input viewport, including map/settings choices.
	if not node is Window or node.has_meta("display_shortcut"): return
	node.set_meta("display_shortcut",true)
	node.window_input.connect(func(event):
		if handle_display_shortcut(event): node.set_input_as_handled())

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or dialog.visible or help_dialog.visible: return
	if menu!=null and menu.visible:
		if event.keycode==KEY_ESCAPE: menu.back();get_viewport().set_input_as_handled()
		return
	var action=settings.action_for(event)
	if map_tools.visible:
		if event.keycode==KEY_ESCAPE: map_tools.visible=false
		elif action=="pause": toggle_pause()
		return
	if action=="contracts":
		if business.visible: business.visible=false
		else: business.open("offers")
		return
	if action=="company":
		business.open("company")
		return
	if event.keycode==KEY_ESCAPE and business.visible:
		business.visible=false
		return
	if event.keycode==KEY_ESCAPE and is_fullscreen():
		toggle_fullscreen()
		return
	if event.keycode==KEY_ESCAPE: menu.open("pause");return
	match action:
		"inspect","buy","demolish","datacenter","power","cooling": set_tool(action)
		"pause": toggle_pause()
		"speed": cycle_speed()
	match event.keycode:
		KEY_HOME: town.center_view()
		KEY_F5: quicksave()
		KEY_F9: load_saved()
		KEY_F1: show_help()
		KEY_R:
			if sim.rescue():
				dirty=true
				toast("Emergency grant received: $8,000. This grant is available once per town.")
				refresh_hud()

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func toggle_fullscreen() -> void:
	if fullscreen_transition: return
	fullscreen_transition=true
	var mode = DisplayServer.window_get_mode()
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Let Windows restore decorations before restoring the saved client rectangle.
		await get_tree().process_frame
		DisplayServer.window_set_size(windowed_size)
		DisplayServer.window_set_position(windowed_position)
		if windowed_mode==DisplayServer.WINDOW_MODE_MAXIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		windowed_mode=mode
		windowed_size = DisplayServer.window_get_size()
		windowed_position = DisplayServer.window_get_position()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Changing ALWAYS_ON_TOP during fullscreen resets the Win32 mode; leave it alone.
	await get_tree().process_frame
	await get_tree().process_frame
	layout_stage()
	fullscreen_transition=false
	if settings!=null:
		settings.fullscreen=is_fullscreen()
		settings.save_settings()

func request_window_close() -> void:
	request_leave(func():get_tree().quit())

func apply_settings(resize_window:bool=false,persist:bool=true) -> void:
	sound_enabled=settings.sound
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,settings.volume)))
	if resize_window:
		if is_fullscreen(): await toggle_fullscreen()
		DisplayServer.window_set_size(settings.resolution)
	apply_text_size(stage)
	for action in tools_buttons:
		set_caption(tools_buttons[action],TOOL_NAMES[action],settings.key_label(action))
	set_caption(contract_button,"Contracts",settings.key_label("contracts"))
	update_sound_button()
	update_time_controls()
	if town!=null:
		town.text_scale=settings.ui_scale
		town.queue_redraw()
	if persist and not settings.save_settings(): toast("Settings could not be saved.")

func apply_text_size(node:Node) -> void:
	if node.has_meta("base_font_size"):
		node.add_theme_font_size_override("font_size",roundi(float(node.get_meta("base_font_size"))*settings.ui_scale))
	for child in node.get_children(): apply_text_size(child)

func focus_lot(index:int) -> void:
	if index<0 or index>=sim.lots.size(): return
	on_selected(index)
	town.selected=index
	town.focus(index)

func focus_alert() -> void:
	if not sim.operations_status().is_empty(): business.open("operations");return
	var problems:Array=sim.metrics().disconnected
	if not problems.is_empty(): focus_lot(problems[0])

func site_text(index:int) -> String:
	var kind=tool if tool in Sim.BUILDINGS else "datacenter"
	var p=sim.site_preview(index,kind,build_profile)
	var connections="Power %s · Cooling %s" % ["in reach" if p.power else "missing","in reach" if p.cooling else "missing"]
	var river="\nRiverfront: +25% cooling" if p.river_bonus else ""
	if sim.lots[index].get("preserved",false): return "PERMANENT CONSERVATION\nThis site cannot be cleared.\nIts protection survives heritage hearings and expedited permits."
	if not p.permit_error.is_empty(): return "HALL PERMIT PAUSED\nOpen Town council for remedies.\nUtilities and repairs allowed."
	if sim.lots[index].owned and sim.lots[index].kind=="grass":
		return "%s total: %s\nIncludes access works: %s\n%s%s" % [Sim.BUILDINGS[kind].name,money(p.total),money(p.access),connections,river]
	return "%s total: %s\nLand %s · Clear %s\nBuild %s · Access %s\nHearing %s · Approval -%d\n%s%s" % [Sim.BUILDINGS[kind].name,money(p.total),money(p.land),money(p.clearance),money(Economy.HARDWARE[build_profile].cost if kind=="datacenter" else Sim.BUILDINGS[kind].cost),money(p.access),money(p.hearing),p.approval,connections,river]

func focus_hall_button() -> void:
	for child in inspector.get_children():
		if child is Button and child.text.begins_with("Server hall"):
			child.grab_focus();return

func handle_operation_alerts() -> void:
	var civic_alerts=sim.take_civic_alerts()
	if not civic_alerts.is_empty():
		refresh_inspector()
		for item in civic_alerts: notice_queue.append(Sim.Geography.DISTRICTS[item.ward].name+": "+item.message)
		var urgent_civic=civic_alerts.filter(func(a):return not a.get("routine",false))
		if settings.auto_pause and not urgent_civic.is_empty():
			if not paused: toggle_pause()
			open_town(urgent_civic[-1].ward)
		toast(civic_alerts[-1].message)
	var alerts=sim.take_operation_alerts()
	if alerts.is_empty(): return
	for item in alerts: notice_queue.append(item.message)
	if alerts[-1].lot>=0:
		selected=int(alerts[-1].lot);town.selected=selected;refresh_inspector()
	if settings.auto_pause and alerts.any(func(a):return not a.get("routine",false)):
		if not paused: toggle_pause()
		business.open("operations")
	toast(alerts[-1].message)

func open_town(ward:String="") -> void:
	business.ward=ward if Sim.Geography.DISTRICTS.has(ward) else Sim.Civic.ward_for(sim.lots[maxi(0,selected)])
	if sim.lots[maxi(0,selected)].kind in ["house","park","monument"]:
		Sim.Tutorial.mark(sim,"dilemma");dirty=true
	business.open("town")

func update_guide() -> void:
	if is_instance_valid(guided_control) and guided_style!=null: guided_control.add_theme_stylebox_override("normal",guided_style)
	guided_control=null;guided_style=null
	var step=Sim.Tutorial.current(sim)
	guide_button.text="Guide" if not sim.tutorial.enabled or step.is_empty() else "%d / 9" % (sim.tutorial.done.size()+1)
	guide_button.tooltip_text="Open the introduction checklist. You can skip or resume guidance."
	if not sim.tutorial.enabled or step.is_empty(): return
	objective.text="GUIDE / "+step.title
	objective_detail.text=step.hint;objective_detail.tooltip_text=step.hint
	var targets={"inspect":tools_buttons.inspect,"buy":tools_buttons.buy,"demolish":tools_buttons.demolish,"datacenter":tools_buttons.datacenter,"run":pause_button,"contracts":contract_button,"upgrade":contract_button,"operations":operations_button,"council":council_button}
	guided_control=targets.get(step.action)
	if step.action=="upgrade":
		for child in inspector.get_children():
			if child is Button and child.text.begins_with("Upgrade"): guided_control=child;break
	if is_instance_valid(guided_control):
		guided_style=guided_control.get_theme_stylebox("normal")
		var highlight=guided_style.duplicate();highlight.border_color=GOLD;highlight.set_border_width_all(2)
		guided_control.add_theme_stylebox_override("normal",highlight)

func guide_next() -> void:
	var step=Sim.Tutorial.current(sim)
	if step.is_empty(): business.open("scenario");return
	match step.action:
		"inspect","buy","demolish","datacenter": focus_lot(83)
		"contracts": business.open("offers")
		"upgrade": focus_lot(83)
		"operations": business.open("operations")
		"council":
			for i in range(sim.lots.size()):
				if sim.lots[i].kind=="monument": focus_lot(i);break
			open_town()
		"run": toast("Space runs or pauses. F4 changes speed. Time is under your control.")
	refresh_hud()
