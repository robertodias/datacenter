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
	draw_rect(Rect2(Vector2.ZERO,size),Color("b8a86d") if sim.scenario_id=="sunsprawl" else Color("84a75f"))
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
				if lot.kind=="grass" and not lot.owned and (x*3+y)%4==0: objects.append({"depth":x+y+0.9,"type":"tree","x":x+0.74,"y":y+0.22,"variant":x+y})
				if lot.kind=="road" and x!=y and (x+y)%2==0: objects.append({"depth":x+y+1.0,"type":"lamp","x":x+0.91,"y":y+0.09})
			elif x not in [4,12] and y not in [4,12]:
				if noise_at(x,y,8)<0.26: objects.append({"depth":x+y+1,"type":"tree","x":x+0.5,"y":y+0.5,"variant":posmod(x+y,4)})
				if x>=17 and y<3 and y> -5:
					art.ground(x+0.1,y+0.1,0.8,0.8,Color("a9ad5c"))
					for row in range(5): art.ground(x+0.15,y+0.15+row*0.15,0.7,0.04,Color("c2b36a"))
	parent_view.static_objects=objects
