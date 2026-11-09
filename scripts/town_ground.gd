extends "res://scripts/town_view.gd"
## Retained ground canvas: redraw only when camera or land ownership changes.
## Characters, traffic, utility machinery and water flow remain live above it.
var parent_view

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	art=Art.new(self)

func _process(_delta:float) -> void:
	pass

func _draw() -> void:
	if parent_view==null: return
	sim=parent_view.sim;sprites=parent_view.sprites
	origin=parent_view.origin;draw_scale=parent_view.draw_scale
	size=parent_view.size
	draw_rect(Rect2(Vector2.ZERO,size),Color("b8a86d") if sim.scenario_id=="sunsprawl" else Color("6f8f52"))
	var sun:bool=sim.scenario_id=="sunsprawl"
	var lo=Vector2(1000,1000);var hi=Vector2(-1000,-1000)
	for corner in [Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]:
		var p=world(corner);lo=lo.min(p);hi=hi.max(p)
	var objects:Array=[]
	for y in range(int(floor(lo.y))-2,int(ceil(hi.y))+2):
		for x in range(int(floor(lo.x))-2,int(ceil(hi.x))+2):
			var screen=point(x+0.5,y+0.5)
			if screen.x< -100 or screen.y< -100 or screen.x>size.x+100 or screen.y>size.y+120: continue
			var lot:Dictionary=sim.lot_at(x,y);baked_ground(x,y,lot)
			if not lot.is_empty():
				if lot.kind not in ["grass","road","water"]: objects.append({"depth":x+y+1.25,"type":"building","data":lot})
				if lot.kind=="grass" and not lot.owned:
					if (x*3+y)%4==0: objects.append({"depth":x+y+0.96,"type":"prop","key":tree_key(x,y,sun),"x":x+0.74,"y":y+0.22})
					elif (x+y*5)%7==0: objects.append({"depth":x+y+1.2,"type":"prop","key":(choose(["prop_cactus_0","prop_cactus_1"],x,y,13) if sun else choose(["bush_0","bush_1","bush_2","flowerbed_0","flowerbed_1"],x,y,13)),"x":x+0.3,"y":y+0.72})
				if lot.kind=="road" and x!=y and (x+y)%2==0:
					var lamp="street_lamp_classic" if lot.district=="oldtown" or sim.scenario_id=="oldbridge" else "street_lamp_modern"
					objects.append({"depth":x+y+1.0,"type":"prop","key":lamp,"x":x+0.91,"y":y+0.09})
			if RIVER_PROPS.has(Vector2i(x,y)) and is_river(x,y) and y not in [4,12]:
				objects.append({"depth":x+y+1.0,"type":"prop","key":RIVER_PROPS[Vector2i(x,y)],"x":x+0.5,"y":y+0.5})
			if lot.is_empty() and x not in [4,12] and y not in [4,12] and not is_river(x,y):
				if COUNTRY_PROPS.has(Vector2i(x,y)) and not sun:
					objects.append({"depth":x+y+1,"type":"prop","key":COUNTRY_PROPS[Vector2i(x,y)],"x":x+0.5,"y":y+0.5})
				elif not is_field(x,y) and noise_at(x,y,8)<0.26:
					var key=tree_key(x,y,sun)
					if not sun and noise_at(x,y,9)<0.35: key=choose(["forest_clump_0","forest_clump_1","forest_clump_2"],x,y,10)
					objects.append({"depth":x+y+1,"type":"prop","key":key,"x":x+0.5,"y":y+0.5})
	parent_view.static_objects=objects
	draw_outside_veil()

func tree_key(x:int,y:int,sun:bool) -> String:
	if sun: return choose(["prop_palm_0","prop_palm_1","prop_palm_0","prop_cactus_0"],x,y,12)
	return choose(["tree_round_0","tree_round_1","tree_round_2","tree_round_3","tree_round_4","tree_round_5","tree_pine_0","tree_pine_1","tree_pine_2"],x,y,12)

## Darken and cool the countryside outside the town limits, with a soft inner edge,
## so the playable area reads at a glance (land beyond is not part of the town).
func draw_outside_veil() -> void:
	var veil=Color(0.06,0.13,0.12,0.42)
	var n=TOWN_SIZE
	var top=point(0,0);var right=point(n,0);var bottom=point(n,n);var left=point(0,n)
	if size.x<4 or size.y<4 or draw_scale<=0.001: return
	# The screen box must enclose the town diamond, or the quads fold over themselves.
	var far=maxf(size.x,size.y)*4
	for corner in [top,right,bottom,left]: far=maxf(far,maxf(absf(corner.x),absf(corner.y))*2)
	var screen=[Vector2(-far,-far),Vector2(size.x+far,-far),Vector2(size.x+far,size.y+far),Vector2(-far,size.y+far)]
	# Four quadrilaterals between the town diamond and the screen corners.
	draw_colored_polygon(PackedVector2Array([screen[0],screen[1],right,top]),veil)
	draw_colored_polygon(PackedVector2Array([screen[1],screen[2],bottom,right]),veil)
	draw_colored_polygon(PackedVector2Array([screen[2],screen[3],left,bottom]),veil)
	draw_colored_polygon(PackedVector2Array([screen[3],screen[0],top,left]),veil)
	# Soft falloff band just outside the boundary.
	for k in range(1,4):
		var g=k*0.35
		var ring=[point(-g,-g),point(n+g,-g),point(n+g,n+g),point(-g,n+g)]
		var pts=PackedVector2Array(ring);pts.append(ring[0])
		draw_polyline(pts,Color(0.06,0.13,0.12,0.10),maxf(2,(10-k*2)*draw_scale),true)
