extends Control
signal focused(index:int)
var game
var padding=20.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	tooltip_text="Click a parcel to focus it in the town. Gold outlines mark protected land."

func _process(_delta:float) -> void:
	if is_visible_in_tree(): queue_redraw()

func _draw() -> void:
	if game==null: return
	var step=(size-Vector2.ONE*padding*2)/game.sim.MAP_SIZE
	draw_rect(Rect2(Vector2.ZERO,size),Color("142d2b"))
	for lot in game.sim.lots:
		var color={"road":Color("a3a897"),"water":Color("65b2bc"),"house":Color("bc9471"),"warehouse":Color("a69d7e"),"park":Color("527d4c"),"monument":Color("ead295"),"datacenter":Color("a5dfbc"),"power":Color("e1c66e"),"cooling":Color("88b6e4")}.get(lot.kind,Color("55744d"))
		var rect=Rect2(Vector2(padding,padding)+Vector2(lot.x,lot.y)*step,step-Vector2.ONE)
		draw_rect(rect,color)
		if lot.get("protected",false): draw_rect(rect,Color("f6e5ac"),false,1)
		if game.selected==game.sim.cell(int(lot.x),int(lot.y)): draw_rect(rect.grow(1),Color.WHITE,false,2)
		if lot.kind in ["datacenter","power","cooling"]:
			var mark={"datacenter":"H","power":"P","cooling":"C"}[lot.kind]
			draw_string(ThemeDB.fallback_font,rect.position+Vector2(5,step.y-7),mark,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("142d2b"))
	var font=ThemeDB.fallback_font
	for coord in [0,3,7,11,15]:
		draw_string(font,Vector2(padding+coord*step.x+4,14),str(coord+1),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e2e9dc"))
		draw_string(font,Vector2(2,padding+(coord+0.7)*step.y),str(coord+1),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e2e9dc"))
	var boundary=PackedVector2Array([Vector2(padding,padding),Vector2(size.x-padding,padding),size-Vector2.ONE*padding,Vector2(padding,size.y-padding)])
	for polygon in Geometry2D.intersect_polygons(camera_footprint(),boundary):
		draw_colored_polygon(polygon,Color(1,1,1,0.06))
		var line=polygon.duplicate();line.append(line[0]);draw_polyline(line,Color("fff0b8"),2,true)

func camera_footprint() -> PackedVector2Array:
	var step=(size-Vector2.ONE*padding*2)/game.sim.MAP_SIZE
	var area:Rect2=game.town.play_area
	var result=PackedVector2Array()
	for corner in [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]:
		result.append(Vector2.ONE*padding+game.town.world(corner)*step)
	return result

func _gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var cell=((event.position-Vector2.ONE*padding)/(size-Vector2.ONE*padding*2)*game.sim.MAP_SIZE).floor()
		if cell.x>=0 and cell.y>=0 and cell.x<game.sim.MAP_SIZE and cell.y<game.sim.MAP_SIZE:
			focused.emit(game.sim.cell(int(cell.x),int(cell.y)))
