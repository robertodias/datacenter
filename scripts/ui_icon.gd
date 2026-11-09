extends Control
## Vector interface glyphs drawn in code on a 24×24 design grid. No external art.
## Every glyph is a simple silhouette so it stays legible from 14 to 40 pixels.

var glyph := "inspect":
	set(value):
		glyph = value
		queue_redraw()
var tint := Color("e2e9dc"):
	set(value):
		tint = value
		queue_redraw()

func _init(name_:String="inspect", color:Color=Color("e2e9dc")) -> void:
	glyph = name_
	tint = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _p(x:float, y:float) -> Vector2:
	var s := minf(size.x, size.y) / 24.0
	var offset := (size - Vector2(24, 24) * s) / 2.0
	return offset + Vector2(x, y) * s

func _w(width:float=2.0) -> float:
	return maxf(1.0, width * minf(size.x, size.y) / 24.0)

func _line(points:Array, width:float=2.0, closed:bool=false) -> void:
	var pts := PackedVector2Array()
	for p in points: pts.append(_p(p.x, p.y))
	if closed: pts.append(pts[0])
	draw_polyline(pts, tint, _w(width), true)

func _fill(points:Array, color:Color=Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array()
	for p in points: pts.append(_p(p.x, p.y))
	draw_colored_polygon(pts, tint if color.a == 0 else color)

func _circle(x:float, y:float, r:float, filled:bool=false, width:float=2.0) -> void:
	var s := minf(size.x, size.y) / 24.0
	if filled: draw_circle(_p(x, y), r * s, tint)
	else: draw_arc(_p(x, y), r * s, 0, TAU, 28, tint, _w(width), true)

func _arc(x:float, y:float, r:float, from:float, to:float, width:float=2.0) -> void:
	var s := minf(size.x, size.y) / 24.0
	draw_arc(_p(x, y), r * s, from, to, 20, tint, _w(width), true)

func _rect(x:float, y:float, w:float, h:float, filled:bool=false, width:float=2.0) -> void:
	if filled: _fill([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	else: _line([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)], width, true)

func _draw() -> void:
	match glyph:
		"inspect":
			_circle(10, 10, 6)
			_line([Vector2(14.5, 14.5), Vector2(20, 20)], 3)
		"buy":
			_line([Vector2(3, 12), Vector2(12, 3), Vector2(21, 3), Vector2(21, 12), Vector2(12, 21)], 2, true)
			_circle(16.5, 7.5, 1.6, true)
		"demolish":
			_line([Vector2(4, 20), Vector2(13, 11)], 3)
			_fill([Vector2(11, 5), Vector2(17, 3), Vector2(21, 7), Vector2(19, 13), Vector2(13, 11)])
			_line([Vector2(3, 21), Vector2(10, 21)], 2)
		"datacenter":
			_rect(5, 3, 14, 18)
			for y in [7.5, 12, 16.5]:
				_line([Vector2(8, y), Vector2(13, y)], 2)
				_circle(16, y, 1.1, true)
		"power":
			_fill([Vector2(13, 2), Vector2(5, 14), Vector2(11, 14), Vector2(10, 22), Vector2(19, 9), Vector2(13, 9)])
		"cooling":
			for a in [PI / 2, PI / 2 + PI / 3, PI / 2 + 2 * PI / 3]:
				var d := Vector2(cos(a), sin(a)) * 9.5
				_line([Vector2(12, 12) - d, Vector2(12, 12) + d], 2)
				for side in [-1.0, 1.0]:
					var inner: Vector2 = Vector2(12, 12) + d * side * 0.55
					var tip: Vector2 = Vector2(12, 12) + d * side * 0.85
					var n: Vector2 = Vector2(-d.y, d.x).normalized() * 2.8
					_line([tip + n, inner, tip - n], 1.6)
		"contracts":
			_line([Vector2(6, 3), Vector2(15, 3), Vector2(19, 7), Vector2(19, 21), Vector2(6, 21)], 2, true)
			_line([Vector2(15, 3), Vector2(15, 7), Vector2(19, 7)], 1.6)
			for y in [11.0, 14.5, 18.0]: _line([Vector2(9, y), Vector2(16, y)], 1.6)
		"company":
			_rect(3, 8, 18, 12)
			_line([Vector2(9, 8), Vector2(9, 5), Vector2(15, 5), Vector2(15, 8)], 2)
			_line([Vector2(3, 13), Vector2(21, 13)], 1.6)
		"operations":
			_arc(12, 13, 8, PI * 0.8, PI * 2.2, 2.4)
			_line([Vector2(12, 13), Vector2(16.5, 8)], 2.4)
			_circle(12, 13, 1.8, true)
			_line([Vector2(8, 21), Vector2(16, 21)], 2)
		"council":
			_fill([Vector2(2, 9), Vector2(12, 3), Vector2(22, 9)])
			for x in [5.0, 9.7, 14.3, 19.0]: _line([Vector2(x, 11), Vector2(x, 18)], 2.2)
			_line([Vector2(3, 20.5), Vector2(21, 20.5)], 2.4)
		"research":
			_rect(7, 7, 10, 10)
			for k in [9.5, 14.5]:
				_line([Vector2(k, 3), Vector2(k, 7)], 1.6); _line([Vector2(k, 17), Vector2(k, 21)], 1.6)
				_line([Vector2(3, k), Vector2(7, k)], 1.6); _line([Vector2(17, k), Vector2(21, k)], 1.6)
			_circle(12, 12, 1.8, true)
		"map":
			_line([Vector2(3, 6), Vector2(9, 3), Vector2(15, 6), Vector2(21, 3), Vector2(21, 18), Vector2(15, 21), Vector2(9, 18), Vector2(3, 21)], 2, true)
			_line([Vector2(9, 3), Vector2(9, 18)], 1.6); _line([Vector2(15, 6), Vector2(15, 21)], 1.6)
		"layers":
			_line([Vector2(12, 4), Vector2(21, 9), Vector2(12, 14), Vector2(3, 9)], 2, true)
			_line([Vector2(3, 13), Vector2(12, 18), Vector2(21, 13)], 2)
			_line([Vector2(3, 17), Vector2(12, 22), Vector2(21, 17)], 2)
		"menu":
			for y in [6.0, 12.0, 18.0]: _line([Vector2(4, y), Vector2(20, y)], 2.4)
		"help":
			_circle(12, 12, 9.5)
			_arc(12, 9.5, 3.2, PI, PI * 2.25, 2.2)
			_line([Vector2(12, 12.6), Vector2(12, 14.5)], 2.2)
			_circle(12, 17.6, 1.3, true)
		"sound", "sound_off":
			_fill([Vector2(3, 9), Vector2(8, 9), Vector2(13, 4), Vector2(13, 20), Vector2(8, 15), Vector2(3, 15)])
			if glyph == "sound":
				_arc(13, 12, 4.5, -PI / 3, PI / 3, 2); _arc(13, 12, 8, -PI / 3, PI / 3, 2)
			else:
				_line([Vector2(16, 9), Vector2(22, 15)], 2); _line([Vector2(22, 9), Vector2(16, 15)], 2)
		"cash":
			_circle(12, 12, 9.5)
			_arc(12, 9.6, 2.8, PI * 0.25, PI * 1.5, 2)
			_arc(12, 14.4, 2.8, PI * 1.25, PI * 2.5, 2)
			_line([Vector2(12, 5), Vector2(12, 19)], 1.6)
		"profit":
			_line([Vector2(3, 18), Vector2(9, 12), Vector2(13, 15), Vector2(21, 6)], 2.4)
			_line([Vector2(15, 6), Vector2(21, 6), Vector2(21, 12)], 2.4)
		"compute":
			_rect(4, 5, 16, 14)
			_line([Vector2(8, 10), Vector2(10, 12), Vector2(8, 14)], 2)
			_line([Vector2(12, 14), Vector2(16, 14)], 2)
		"approval":
			_circle(12, 8, 4)
			_line([Vector2(4, 21), Vector2(5, 17), Vector2(9, 14), Vector2(15, 14), Vector2(19, 17), Vector2(20, 21)], 2.2)
		"pause":
			_rect(6, 4, 4, 16, true); _rect(14, 4, 4, 16, true)
		"play":
			_fill([Vector2(7, 4), Vector2(20, 12), Vector2(7, 20)])
		"speed":
			_fill([Vector2(3, 5), Vector2(12, 12), Vector2(3, 19)]); _fill([Vector2(12, 5), Vector2(21, 12), Vector2(12, 19)])
		"fullscreen":
			for c in [[Vector2(3, 9), Vector2(3, 3), Vector2(9, 3)], [Vector2(15, 3), Vector2(21, 3), Vector2(21, 9)], [Vector2(21, 15), Vector2(21, 21), Vector2(15, 21)], [Vector2(9, 21), Vector2(3, 21), Vector2(3, 15)]]:
				_line(c, 2.2)
		"alert":
			_line([Vector2(12, 3), Vector2(22, 20), Vector2(2, 20)], 2, true)
			_line([Vector2(12, 9), Vector2(12, 14)], 2.4)
			_circle(12, 17, 1.3, true)
		"close":
			_line([Vector2(5, 5), Vector2(19, 19)], 2.4); _line([Vector2(19, 5), Vector2(5, 19)], 2.4)
		"lock":
			_rect(5, 11, 14, 10, true)
			_arc(12, 11, 4.5, PI, TAU, 2.4)
		"check":
			_line([Vector2(4, 13), Vector2(10, 19), Vector2(20, 6)], 3)
		"people":
			_circle(8.5, 8, 3); _circle(16, 9, 2.6)
			_line([Vector2(3, 20), Vector2(4, 15), Vector2(13, 15), Vector2(14, 20)], 2)
			_line([Vector2(15, 14), Vector2(19.5, 14), Vector2(21, 19)], 1.8)
		"trophy":
			_line([Vector2(7, 4), Vector2(17, 4), Vector2(16, 11), Vector2(12, 14), Vector2(8, 11)], 2, true)
			_line([Vector2(7, 6), Vector2(3, 6), Vector2(4, 10), Vector2(8, 11)], 1.6)
			_line([Vector2(17, 6), Vector2(21, 6), Vector2(20, 10), Vector2(16, 11)], 1.6)
			_line([Vector2(12, 14), Vector2(12, 18)], 2); _line([Vector2(7, 20.5), Vector2(17, 20.5)], 2.4)
		"flag":
			_line([Vector2(5, 21), Vector2(5, 3)], 2.2)
			_fill([Vector2(5, 3), Vector2(19, 6), Vector2(5, 11)])
		"guide":
			_line([Vector2(3, 5), Vector2(10, 5), Vector2(12, 7), Vector2(12, 20), Vector2(10, 18), Vector2(3, 18)], 2, true)
			_line([Vector2(21, 5), Vector2(14, 5), Vector2(12, 7), Vector2(12, 20), Vector2(14, 18), Vector2(21, 18)], 2, true)
		"save":
			_line([Vector2(4, 4), Vector2(17, 4), Vector2(20, 7), Vector2(20, 20), Vector2(4, 20)], 2, true)
			_rect(8, 4, 7, 5); _rect(7, 13, 10, 7, true)
		_:
			_circle(12, 12, 8)
