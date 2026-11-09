extends Control
## Thin capacity gauge. Fill colour shifts from healthy to warning to critical as
## the used share approaches capacity, so shortages read at a glance (not colour alone:
## the numeric value is always shown beside it).

const TRACK = Color(0.03, 0.09, 0.08, 0.85)
const HEALTHY = Color("7fd3a4")
const WARNING = Color("e9c46a")
const CRITICAL = Color("ef7d62")

var value := 0.0
var maximum := 1.0
var warn_at := 0.85
var invert := false   # true: high values are good (approval)
var fixed_color := Color(0, 0, 0, 0)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_values(v:float, m:float) -> void:
	if is_equal_approx(v, value) and is_equal_approx(m, maximum): return
	value = v
	maximum = m
	queue_redraw()

func ratio() -> float:
	return clampf(value / maximum, 0, 1) if maximum > 0 else (1.0 if value > 0 else 0.0)

func fill_color() -> Color:
	if fixed_color.a > 0: return fixed_color
	var r := ratio()
	if invert:
		return CRITICAL if r < 0.4 else (WARNING if r < 0.6 else HEALTHY)
	if maximum <= 0 and value > 0: return CRITICAL
	if value > maximum + 0.001: return CRITICAL
	return WARNING if r >= warn_at else HEALTHY

func _draw() -> void:
	var radius := size.y / 2.0
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK
	track.set_corner_radius_all(int(radius))
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	var w := size.x * ratio()
	if w <= 0.5: return
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color()
	fill.set_corner_radius_all(int(radius))
	draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(w, size.y), size.y)))
