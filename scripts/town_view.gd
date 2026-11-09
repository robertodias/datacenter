extends Control
signal lot_selected(index:int)
## Left click with a construction tool: the game applies that tool to the plot.
signal lot_activated(index:int)
const Sim=preload("res://scripts/simulation.gd")
const Art=preload("res://scripts/town_art.gd")
var sim
var art
var selected=83
var hovered=-1
var hovered_person=-1
var tool="inspect"
var build_profile="balanced"
var time=0.0
var work_fraction=0.0
var activity_speed=1.0
var zoom=1.0
var fit_scale=1.0
var draw_scale=1.0
var pan=Vector2.ZERO
var dragging=false
var effects:Array=[]
var origin=Vector2.ZERO
var tile=Vector2(56,28)
var play_area=Rect2(20,185,1080,535)
var font:Font=ThemeDB.fallback_font
var pedestrians:Array=[]
var vehicles:Array=[]
var mouse_position=Vector2(-1000,-1000)
var rng=RandomNumberGenerator.new()
var network:Dictionary={}
var sprites:Dictionary={}
var overlay="Town view"
var overlay_cells:Array=[]
var overlay_key=""
var ground_canvas
var ground_key=""
var static_objects:Array=[]
var text_scale=1.0
var thought_panel:PanelContainer
var thought_label:Label
## Returns {text, tone} for the plot under the cursor while a tool is active.
var cost_tag:Callable
## The playable town is 16 x 16 plots. Everything beyond is countryside: drawn so the
## edges of any screen are filled, but veiled and out of bounds, like the land beyond a
## park fence. The camera keeps the town in view.
const TOWN_SIZE=16
## Construction feedback plays in real time (also while paused): site prep, a rising
## frame under a crane, then the finished building. Demolition shakes, sinks into a
## dust cloud and leaves rubble that clears. The simulation result is immediate.
const BUILD_SECONDS=3.2
const UPGRADE_SECONDS=2.0
const DEMOLISH_SECONDS=2.4
var anims:Dictionary={}
var real_time:=0.0
var reduced_motion:=false
var ghost_valid:Callable
## Plots with a construction or upgrade crew at work (refreshed every frame).
var crane_sites:Dictionary={}
const OUTSIDE_TINT=Color(0.56,0.64,0.6)
## Traffic models, one per car slot (see assets/art/vehicles).
const CAR_MODELS=["bus_city","car_hatch_a","car_sedan_a","van_delivery","car_suv_a","car_hatch_c","car_hatch_b","car_sedan_b","truck_box","car_hatch_d",
	"bus_city","car_suv_b","car_hatch_a","van_delivery","car_sedan_a","car_hatch_c"]
const SHOPS=["shop_bakery","shop_cafe","shop_books","shop_grocer","shop_pharmacy","shop_hardware"]
## Canvas point of a plot's centre on the 256 sprite canvas: props are painted here.
const PLOT_CENTRE=Vector2(128,178)
const BUS_STOPS=[Vector2i(6,12),Vector2i(14,4)]
const RIVER_PROPS={Vector2i(8,1):"prop_reeds",Vector2i(9,2):"prop_ducks",Vector2i(8,7):"prop_reeds",Vector2i(9,9):"prop_rowboat",Vector2i(8,10):"prop_ducks",Vector2i(9,14):"prop_reeds",Vector2i(8,15):"prop_dock",Vector2i(9,-3):"prop_barge",Vector2i(8,19):"prop_rowboat"}
const COUNTRY_PROPS={Vector2i(18,0):"farm_barn",Vector2i(17,-2):"farm_silo",Vector2i(19,2):"haybales",Vector2i(-3,9):"wind_turbine",Vector2i(-4,13):"wind_turbine",Vector2i(20,10):"cell_tower",Vector2i(-2,-3):"farm_barn",Vector2i(19,15):"rock_1",Vector2i(-3,2):"rock_0"}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	art=Art.new(self)
	# The painted sprites are detailed and usually drawn at a third of their size: mipmaps
	# keep them crisp instead of shimmering.
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	load_sprites()
	ground_canvas=load("res://scripts/town_ground.gd").new()
	ground_canvas.parent_view=self;ground_canvas.z_index=-1
	add_child(ground_canvas)
	rng.seed=12275
	for i in range(48):
		var pos=Vector2(rng.randi_range(0,7)+0.06,rng.randi_range(0,15)+0.06)
		pedestrians.append({"pos":pos,"goal":pos,"route":[],"wait":rng.randf_range(0,4),"pace":rng.randf_range(0.18,0.28),"phase":rng.randf()*TAU,"variant":i%8,"resident_id":i,"purpose":"Heading home","destination":-1,"name":["Maya","Leo","Nora","Oliver","Ana","Sam","Iris","Ben"][i%8]})
	for i in range(16):
		var model:String=CAR_MODELS[i]
		vehicles.append({"at":float(i)*1.35,"axis":i%2,"dir":1 if i%4<2 else -1,"type":i%5,"model":model,"pace":0.50 if model in ["bus_city","truck_box"] else 0.72,"road":4 if i<10 else 12})
	thought_panel=PanelContainer.new();thought_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var bubble=bubble_style();bubble.content_margin_left=12;bubble.content_margin_right=12;bubble.content_margin_top=10;bubble.content_margin_bottom=10
	thought_panel.add_theme_stylebox_override("panel",bubble);add_child(thought_panel)
	thought_label=Label.new();thought_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;thought_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	thought_label.custom_minimum_size.x=360;thought_label.add_theme_color_override("font_color",Color("f3eedb"));thought_panel.add_child(thought_label)
	thought_panel.hide()
	update_camera()
	mouse_exited.connect(func():hovered=-1;hovered_person=-1)

func _process(delta:float) -> void:
	var dt=minf(delta,0.1)*activity_speed
	time+=dt
	real_time+=minf(delta,0.1)
	for idx in anims.keys():
		if real_time-anims[idx].t0>anims[idx].dur: anims.erase(idx);invalidate_soft()
	for e in effects: e.life-=delta
	effects=effects.filter(func(e):return e.life>0)
	for person in pedestrians:
		if person.wait>0: person.wait-=dt;continue
		if person.pos.distance_to(person.goal)<0.02:
			if person.route.is_empty():
				var destination=resident_destination(person)
				person.destination=destination.site;person.purpose=destination.purpose
				var target:Dictionary=sim.lots[destination.site]
				var goal=Vector2i(target.x,target.y)
				person.route=walking_route(Vector2i(person.pos.floor()),goal)
				person.wait=rng.randf_range(1.5,6)
			if not person.route.is_empty(): person.goal=person.route.pop_front()
			continue
		person.pos=person.pos.move_toward(person.goal,dt*person.pace)
		person.phase+=dt*8
	for car in vehicles.slice(0,visible_traffic()):
		var coord=-2+car.at if car.dir==1 else 18-car.at
		var red=(fmod(time,16)<8)!=(car.axis==0)
		var junction=4 if coord<8 else 12
		var stop=junction-0.25 if car.dir==1 else junction+1.1
		var dist=(stop-coord)*car.dir
		if red and dist>=0 and dist<0.1: continue
		var advance=dt*car.pace
		if red and dist>0: advance=minf(advance,dist)
		car.at=fmod(car.at+advance,20)
	update_camera();update_hover();update_thought();queue_redraw()

func walking_route(start:Vector2i,goal:Vector2i) -> Array:
	if sim.lot_at(goal.x,goal.y).get("kind","")=="water": return []
	var frontier:Array=[start]
	var visited:Dictionary={start:start}
	while not frontier.is_empty():
		var current:Vector2i=frontier.pop_front()
		if current==goal: break
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:Vector2i=current+direction
			var lot:Dictionary=sim.lot_at(next.x,next.y)
			if lot.is_empty() or lot.kind=="water" or visited.has(next): continue
			visited[next]=current;frontier.append(next)
	if not visited.has(goal): return []
	var result:Array=[]
	var at=goal
	while at!=start:
		result.push_front(Vector2(at)+Vector2(0.06,0.06));at=visited[at]
	return result

func update_camera() -> void:
	fit_scale=minf(play_area.size.x/1860.0,play_area.size.y/1000.0)
	draw_scale=fit_scale*zoom
	origin=play_area.get_center()-Vector2(0,420*draw_scale)+pan
	clamp_pan()
	var key="%s:%s:%s:%s" % [origin,draw_scale,size,sim.cash if sim!=null else 0]
	if ground_canvas!=null and key!=ground_key:
		ground_key=key;ground_canvas.queue_redraw()

func start_build(index:int,upgrade:bool=false) -> void:
	anims[index]={"type":"upgrade" if upgrade else "build","t0":real_time,"dur":UPGRADE_SECONDS if upgrade else BUILD_SECONDS}

func start_demolition(index:int,key:String) -> void:
	anims[index]={"type":"demolish","t0":real_time,"dur":DEMOLISH_SECONDS,"key":key}
	var lot:Dictionary=sim.lots[index]
	effects.append({"x":lot.x,"y":lot.y,"life":1.5})

func anim_progress(index:int) -> float:
	if not anims.has(index): return 1.0
	return clampf((real_time-anims[index].t0)/anims[index].dur,0,1)

func invalidate_soft() -> void:
	queue_redraw()

## True while a campus building is powered, in service and connected (lit sprites, spinning fans).
func lot_online(lot:Dictionary) -> bool:
	if not Sim.Operations.available(lot,sim.hour) or int(lot.get("refit_until",0))>sim.hour: return false
	if lot.kind!="datacenter": return network.get("power",0)>0
	if network.get("efficiency",0)<=0: return false
	var idx=Sim.cell(int(lot.x),int(lot.y))
	return not idx in network.get("disconnected",[]) and not idx in network.get("refitting",[])

## Stable pseudo-random choice for a plot, so the town looks the same every visit.
func choose(options:Array,x:int,y:int,salt:int) -> String:
	return options[mini(int(noise_at(x,y,salt)*options.size()),options.size()-1)]

## The sprite key used for a building as it currently stands (also kept for demolition).
func building_key(lot:Dictionary) -> String:
	var tier=clampi(int(lot.get("level",1)),1,3)
	var x=int(lot.x);var y=int(lot.y)
	var town:String=sim.scenario_id if sim!=null else "littlebrook"
	match lot.kind:
		"datacenter":
			var profile:String=lot.get("hardware","balanced")
			# Training hardware has no single-storey hall: it starts at the tier-2 shell.
			var t=maxi(tier,2) if profile=="training" else tier
			return "hall_%s_t%d_%s" % [profile,t,"on" if lot_online(lot) else "off"]
		"power": return "power_t%d_%s" % [tier,"on" if lot_online(lot) else "off"]
		"cooling":
			var on=lot_online(lot)
			if tier==1 and on and Sim.Geography.river_access(lot): return "cooling_riverfront_t1_on"
			return "cooling_t%d_%s" % [tier,"on" if on else "off"]
		"house": return home_key(lot,town)
		"warehouse":
			if Vector2i(x,y)==Vector2i(3,5): return "ind_warehouse_0"
			return choose(["ind_warehouse_1","ind_workshop","ind_depot","ind_warehouse_2","ind_factory_small","ind_brewery"],x,y,21)
		"park":
			if town=="sunsprawl": return choose(["park_sports_court","park_playground","park_garden"],x,y,22)
			if lot.district=="gardens": return choose(["park_garden","park_pond","park_garden","landmark_fountain","park_playground","landmark_bandstand"],x,y,22)
			return choose(["park_playground","park_garden","park_sports_court","park_pond","landmark_statue"],x,y,22)
		"monument": return monument_key(lot,town)
	return lot.kind

func home_key(lot:Dictionary,town:String) -> String:
	var x=int(lot.x);var y=int(lot.y)
	var roll=noise_at(x,y,23)
	if town=="sunsprawl":
		if lot.district=="market" and roll<0.2: return "shop_diner"
		return choose(["home_stucco_0","home_stucco_1","home_stucco_2","home_stucco_3"],x,y,24)
	if town=="oldbridge":
		if lot.district=="market" and roll<0.35: return choose(SHOPS,x,y,24)
		if roll>0.8: return choose(["home_terrace_0","home_terrace_1","home_terrace_2","home_terrace_3"],x,y,24)
		return choose(["home_townhouse_0","home_townhouse_1","home_townhouse_2","home_townhouse_3"],x,y,24)
	match lot.district:
		"market":
			if roll<0.6: return choose(SHOPS,x,y,24)
			return choose(["home_apartment_0","home_apartment_1","home_apartment_2"],x,y,24)
		"oldtown":
			# The high street along the first road keeps its shops.
			if (x==3 or y==3) and roll<0.45: return choose(SHOPS,x,y,24)
			if roll<0.7: return choose(["home_detached_0","home_detached_1","home_detached_2","home_detached_3","home_detached_4","home_detached_5"],x,y,24)
			return choose(["home_terrace_0","home_terrace_1","home_terrace_2","home_terrace_3"],x,y,24)
		"gardens":
			if roll<0.55: return choose(["home_detached_0","home_detached_1","home_detached_2","home_detached_3","home_detached_4","home_detached_5"],x,y,24)
			return choose(["home_apartment_0","home_apartment_1","home_apartment_2"],x,y,24)
	if roll<0.6: return choose(["home_detached_0","home_detached_1","home_detached_2","home_detached_3","home_detached_4","home_detached_5"],x,y,24)
	return choose(["home_terrace_0","home_terrace_1","home_terrace_2","home_terrace_3"],x,y,24)

func monument_key(lot:Dictionary,town:String) -> String:
	var at=Vector2i(int(lot.x),int(lot.y))
	if town=="oldbridge":
		var named={Vector2i(1,1):"landmark_cathedral",Vector2i(3,2):"civic_guildhall",Vector2i(6,6):"landmark_old_mill",Vector2i(14,9):"civic_library"}
		if named.has(at): return named[at]
	if town=="sunsprawl" and at==Vector2i(11,10): return "civic_water_tower"
	if at==Vector2i(7,2): return "landmark_clock_tower"
	if at==Vector2i(11,10): return "civic_town_hall"
	return choose(["landmark_obelisk","civic_chapel","civic_library","civic_school","civic_post_office"],at.x,at.y,25)

## Preview sprite for the selected construction tool.
func ghost_key(lot:Dictionary) -> String:
	match tool:
		"datacenter": return "hall_%s_t%d_on" % [build_profile,2 if build_profile=="training" else 1]
		"cooling": return "cooling_riverfront_t1_on" if Sim.Geography.river_access(lot) else "cooling_t1_on"
	return tool+"_t1_on"

## Draw part of a sprite: `keep` is the fraction of its height shown. Without `sink` the
## lower part is revealed (rising); with `sink` the upper part slides into the ground.
func sprite_part(key:String,x:float,y:float,keep:float,sink:float=0.0,tint:Color=Color.WHITE,shake:Vector2=Vector2.ZERO) -> void:
	draw_art(key,point(x,y)+shake,tint,1.0,keep,sink>0)

## Tower crane (painted behind the structure) with a swinging hook load.
func draw_crane(lot:Dictionary,alpha:float,load_drop:float=0.5) -> void:
	if alpha<=0.01: return
	var base=point(lot.x,lot.y)
	draw_art("site_crane",base,Color(1,1,1,alpha))
	var hook:Array=sprites["site_crane"].meta.get("hook",[109,119]) if sprites.has("site_crane") else [109,119]
	var top=art_point("site_crane",base,Vector2(hook[0],hook[1]))
	var swing=0.0 if reduced_motion else sin(real_time*2.2)*6
	var load_at=top+Vector2(swing,24+load_drop*30)*draw_scale/1.5
	draw_line(top,load_at,Color(0.2,0.22,0.2,0.8*alpha),maxf(1,draw_scale*0.8))
	draw_rect(Rect2(load_at-Vector2(5,0)*draw_scale/1.5,Vector2(10,6)*draw_scale/1.5),Color(0.54,0.42,0.28,alpha))

## Real-time build feedback: slab, low frame, high frame, then the building rises out of
## the scaffold while the crane works.
func draw_build_anim(lot:Dictionary,index:int) -> void:
	var a:Dictionary=anims[index];var p=anim_progress(index)
	var key=building_key(lot)
	var upgrade=a.type=="upgrade"
	draw_crane(lot,1.0-clampf((p-0.85)/0.15,0,1),fmod(p*3,1))
	if upgrade:
		var reveal=clampf((p-0.05)/0.7,0,1)
		if reveal<1:
			var below=lot.duplicate();below.level=maxi(1,int(lot.level)-1)
			sprite(building_key(below),lot.x,lot.y,Color(1,1,1,1-reveal))
		sprite_part(key,lot.x,lot.y,reveal)
	else:
		var site_alpha=1.0-clampf((p-0.8)/0.2,0,1)
		if p<0.3: sprite_part("site_foundation",lot.x,lot.y,clampf(p/0.08,0.15,1))
		elif p<0.55: sprite("site_foundation",lot.x,lot.y);sprite_part("site_frame_low",lot.x,lot.y,clampf((p-0.3)/0.12,0.1,1))
		else:
			if p>=0.62: sprite("site_frame_high",lot.x,lot.y,Color(1,1,1,site_alpha))
			else: sprite_part("site_frame_high",lot.x,lot.y,clampf((p-0.55)/0.07,0.3,1))
		sprite_part(key,lot.x,lot.y,clampf((p-0.62)/0.33,0,1))
	if p>0.86 and not reduced_motion:
		var t=(p-0.86)/0.14
		for k in range(6):
			var ang=k*TAU/6+t
			var at=point(lot.x+0.5,lot.y+0.5,40)+Vector2(cos(ang),sin(ang)*0.5)*(20+t*24)*draw_scale
			draw_circle(at,(2.5-t*2)*draw_scale,Color(1,0.95,0.6,1-t))

func draw_demolition(lot:Dictionary,a:Dictionary,index:int) -> void:
	var p=anim_progress(index)
	var shake=Vector2.ZERO if reduced_motion else Vector2(sin(real_time*55)*2.5,0)*(1-p)*draw_scale
	# Rubble appears under the sinking building, then clears.
	var rubble=clampf((p-0.25)/0.2,0,1)*clampf((1-p)/0.3,0,1)
	sprite("rubble_%d" % (index%2),lot.x,lot.y,Color(1,1,1,rubble))
	sprite_part(a.key,lot.x,lot.y,clampf(1.0-p/0.75,0,1),maxf(0.001,p),Color(1,0.94,0.86),shake)
	if not reduced_motion and p<0.8:
		for k in range(10):
			var a2=k*2.399+p*3;var t=fmod(p*1.6+k*0.1,1)
			draw_circle(point(lot.x+0.5,lot.y+0.5,8)+Vector2(cos(a2)*t*44,sin(a2)*t*20-t*26)*draw_scale,(4+t*7)*draw_scale,Color(0.86,0.82,0.7,(1-t)*0.45))

static func outside_town(x:float,y:float) -> bool:
	return x<0 or y<0 or x>=TOWN_SIZE or y>=TOWN_SIZE

## Keep the middle of the view inside the town's footprint, so the camera can reach
## every edge plot when zoomed in but never drifts off into empty countryside.
func clamp_pan() -> void:
	var center=origin+Vector2(0,TOWN_SIZE*tile.y)*draw_scale
	var half=Vector2(TOWN_SIZE*tile.x,TOWN_SIZE*tile.y)*draw_scale*0.85
	var mid=play_area.get_center()
	var target=Vector2(clampf(center.x,mid.x-half.x,mid.x+half.x),clampf(center.y,mid.y-half.y,mid.y+half.y))
	if center!=target:
		pan+=target-center
		origin+=target-center

func center_view() -> void:
	zoom=1;pan=Vector2.ZERO;update_camera()

func invalidate() -> void:
	ground_key="";overlay_key=""
	update_camera();queue_redraw()

func focus(index:int) -> void:
	var lot:Dictionary=sim.lots[index]
	zoom=1.8;pan=Vector2.ZERO;update_camera()
	pan=play_area.get_center()-point(lot.x+0.5,lot.y+0.5,10);update_camera()

func point(x:float,y:float,height:float=0) -> Vector2:
	return origin+Vector2((x-y)*tile.x,(x+y)*tile.y-height)*draw_scale

func world(pos:Vector2) -> Vector2:
	var local=(pos-origin)/draw_scale
	return Vector2((local.x/tile.x+local.y/tile.y)*0.5,(local.y/tile.y-local.x/tile.x)*0.5)

func pick(pos:Vector2) -> int:
	var cell=world(pos).floor()
	if cell.x<0 or cell.y<0 or cell.x>=Sim.MAP_SIZE or cell.y>=Sim.MAP_SIZE: return -1
	return Sim.cell(int(cell.x),int(cell.y))

func polygon(points:Array,color:Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func diamond(x:float,y:float,inset:float,height:float=0) -> Array:
	return [point(x+inset,y+inset,height),point(x+1-inset,y+inset,height),point(x+1-inset,y+1-inset,height),point(x+inset,y+1-inset,height)]

func outline(points:Array,color:Color,width:float=1) -> void:
	var path=PackedVector2Array(points);path.append(points[0]);draw_polyline(path,color,width,false)

func box(x:float,y:float,w:float,d:float,h:float,color:Color,base:float=0) -> void:
	var a=point(x,y,base+h);var b=point(x+w,y,base+h)
	var c=point(x+w,y+d,base+h);var e=point(x,y+d,base+h)
	polygon([e,c,point(x+w,y+d,base),point(x,y+d,base)],color.darkened(0.16))
	polygon([b,c,point(x+w,y+d,base),point(x+w,y,base)],color.darkened(0.32))
	polygon([a,b,c,e],color.lightened(0.12))
	draw_line(a,b,color.lightened(0.24),maxf(1,draw_scale));draw_line(a,e,color.lightened(0.24),maxf(1,draw_scale))

func draw_ellipse_at(center:Vector2,radius:Vector2,color:Color) -> void:
	var points=PackedVector2Array()
	for i in range(16):
		var angle=TAU*i/16.0;points.append(center+Vector2(cos(angle),sin(angle))*radius)
	draw_colored_polygon(points,color)

func noise_at(x:int,y:int,salt:int=0) -> float:
	return fposmod(sin(x*127.1+y*311.7+salt*74.7)*43758.5453,1)

## Load sprite records {tex, rect, offset, anchor, meta}. The painted set
## (assets/town_art.json, packed by dev/pack_town_art.gd) wins; the original baked atlas
## stays as a fallback for any key the painted set lacks.
func load_sprites() -> void:
	var atlas=load("res://assets/town_atlas.png")
	var regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_atlas.json"))
	for key in regions:
		var r=regions[key]
		sprites[key]={"tex":atlas,"rect":Rect2(r[0],r[1],r[2],r[3]),"offset":Vector2.ZERO,"anchor":Vector2(128,136),"meta":{}}
	if not FileAccess.file_exists("res://assets/town_art.json"): return
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_art.json"))
	var pages:Array=[]
	for path in data.pages: pages.append(load(path))
	for key in data.sprites:
		var e:Dictionary=data.sprites[key];var r=e.rect
		sprites[key]={"tex":pages[int(e.page)],"rect":Rect2(r[0],r[1],r[2],r[3]),"offset":Vector2(e.offset[0],e.offset[1]),"anchor":Vector2(e.anchor[0],e.anchor[1]),"meta":e}

## Draw a sprite so its canvas point `pivot` (default: its anchor) lands on screen point `at`.
## `keep` < 1 shows only part of its height (see sprite_part).
func draw_art(key:String,at:Vector2,tint:Color=Color.WHITE,scale:float=1.0,keep:float=1.0,sink:bool=false,pivot:Variant=null) -> void:
	if not sprites.has(key) or keep<=0.001 or tint.a<=0.005: return
	var s:Dictionary=sprites[key]
	var factor=draw_scale/1.5*scale
	var anchor:Vector2=s.anchor if pivot==null else pivot
	var r:Rect2=s.rect
	var dest=Rect2(at+(s.offset-anchor)*factor,r.size*factor)
	if keep>=0.999:
		draw_texture_rect_region(s.tex,dest,r,tint);return
	var src=Rect2(r.position,Vector2(r.size.x,r.size.y*keep)) if sink else Rect2(r.position+Vector2(0,r.size.y*(1-keep)),Vector2(r.size.x,r.size.y*keep))
	draw_texture_rect_region(s.tex,Rect2(dest.position+Vector2(0,dest.size.y*(1-keep)),Vector2(dest.size.x,dest.size.y*keep)),src,tint)

## Screen position of a canvas pixel of a sprite drawn with its anchor at `base`.
func art_point(key:String,base:Vector2,pixel:Vector2,scale:float=1.0) -> Vector2:
	var anchor:Vector2=sprites[key].anchor if sprites.has(key) else Vector2(128,136)
	return base+(pixel-anchor)*draw_scale/1.5*scale

## Screen y of the top of a sprite drawn on plot (x, y).
func sprite_top(key:String,x:float,y:float) -> float:
	if not sprites.has(key): return point(x+0.5,y+0.5,87).y
	var s:Dictionary=sprites[key]
	return point(x,y).y+(s.offset.y-s.anchor.y)*draw_scale/1.5

func sprite(key:String,x:float,y:float,tint:Color=Color.WHITE) -> void:
	draw_art(key,point(x,y),tint)

## A prop painted at its canvas plot centre, placed at world point (x, y).
func prop(key:String,x:float,y:float,tint:Color=Color.WHITE,scale:float=1.0) -> void:
	draw_art(key,point(x,y),tint,scale,1.0,false,PLOT_CENTRE)

func is_river(x:int,y:int) -> bool:
	return x in [8,9] and (sim==null or sim.scenario_id!="sunsprawl")

func terrain_key(x:int,y:int) -> String:
	if sim!=null and sim.scenario_id=="sunsprawl":
		return "sand_0" if noise_at(x,y,3)<0.08 else choose(["dry_grass_0","dry_grass_1","dry_grass_2","dry_grass_3"],x,y,5)
	if noise_at(x,y,3)<0.12: return choose(["meadow_0","meadow_1"],x,y,5)
	return choose(["grass_0","grass_1","grass_2","grass_3","grass_4","grass_5"],x,y,5)

## Countryside beyond the town limits: fields come in 3 x 3 blocks so they read as farms.
func countryside_key(x:int,y:int) -> String:
	var bx=floori(x/3.0);var by=floori(y/3.0)
	var block=noise_at(bx,by,11)
	if sim!=null and sim.scenario_id=="sunsprawl":
		return "field_fallow_0" if block<0.2 else terrain_key(x,y)
	if block<0.22: return ["farm_rows_0","farm_rows_1","farm_rows_2"][posmod(bx+by,3)]
	if block<0.3: return "orchard_0"
	if block<0.36: return "field_fallow_0"
	return terrain_key(x,y)

func is_field(x:int,y:int) -> bool:
	return countryside_key(x,y) in ["farm_rows_0","farm_rows_1","farm_rows_2","orchard_0","field_fallow_0"]

func baked_ground(x:int,y:int,lot:Dictionary) -> void:
	var town:String=sim.scenario_id if sim!=null else "littlebrook"
	var road_x=x in [4,12];var road_y=y in [4,12]
	var key:String
	if is_river(x,y) and road_y: key="bridge_stone_arch_x" if town=="oldbridge" else "bridge_road_x"
	elif is_river(x,y): key="water_bank_nw" if x==8 else "water_bank_se"
	elif road_x and road_y: key="junction_0"
	elif road_y:
		if y==4 and x in [3,5]: key="crossing_x"
		elif Vector2i(x,y) in BUS_STOPS: key="road_bus_stop_x"
		else: key=choose(["road_x_0","road_x_1"],x,y,7)
	elif road_x: key="crossing_y" if x==4 and y in [3,5] else choose(["road_y_0","road_y_1"],x,y,7)
	elif lot.is_empty(): key=countryside_key(x,y)
	elif town=="oldbridge" and lot.kind=="monument": key=choose(["plaza_cobble_0","plaza_cobble_1"],x,y,9)
	elif lot.owned and town!="sunsprawl": key="lot_owned"
	else: key=terrain_key(x,y)
	# Flat tiles overlap a hair so filtering never opens seams between them.
	var tint=OUTSIDE_TINT if outside_town(x,y) else Color.WHITE
	draw_art(key,point(x+0.5,y+0.5),tint,1.02,1.0,false,PLOT_CENTRE)
	if not lot.is_empty() and lot.kind not in ["road","water"]:
		if lot.owned and town=="sunsprawl": outline(diamond(x,y,0.06),Color(0.62,0.95,0.78,0.75),maxf(1,draw_scale*1.5))
		elif not lot.owned and lot.kind=="grass": outline(diamond(x,y,0.07),Color(1,0.98,0.86,0.22),maxf(1,draw_scale))
	if lot.get("protected",false): outline(diamond(x,y,0.04),Color(0.95,0.85,0.5,0.7),1)

func baked_building(lot:Dictionary) -> void:
	var tier=int(lot.get("level",1))
	var index=Sim.cell(int(lot.x),int(lot.y))
	if anims.has(index) and anims[index].type in ["build","upgrade"]:
		draw_build_anim(lot,index);return
	var key=building_key(lot)
	var base=point(lot.x,lot.y)
	var meta:Dictionary=sprites[key].meta if sprites.has(key) else {}
	var hub=lot.kind=="power" and sim.ops.hub==index
	if hub:
		# Generator sets stand behind the substation, battery containers in front.
		for i in range(int(sim.ops.generators)):
			var at=Vector2(lot.x+0.2+i*0.19,lot.y+0.16)
			prop("power_generator_module",at.x,at.y,Color.WHITE,0.3)
			if network.get("generator_output",0)>0:
				var stack=point(at.x,at.y)+(Vector2(173,95)-PLOT_CENTRE)*draw_scale/1.5*0.3
				for k in range(3):
					var t=fmod(time*0.45+i*0.33+k*0.33,1)
					art.ellipse(stack+Vector2(t*6,-t*22)*draw_scale,Vector2(3+t*4,2+t*2),Color(0.4,0.45,0.4,(1-t)*0.6))
	# A crew job on site keeps a crane working behind the building.
	if crane_sites.has(index): draw_crane(lot,1.0,0.5+sin(time*0.8+index)*0.5)
	sprite(key,lot.x,lot.y)
	if hub:
		for i in range(int(sim.ops.batteries)):
			prop("power_battery_module",lot.x+0.2+(i%6)*0.17,lot.y+0.86+(i/6)*0.16,Color.WHITE if sim.ops.charge>0 else Color(0.7,0.74,0.72),0.28)
	if lot.get("quiet",false): draw_acoustic_barrier(lot)
	if lot.kind in ["cooling","datacenter","power"] and meta.has("fans"):
		var running=network.get("power",0)>0 and lot_online(lot)
		var fans:Array=meta.fans
		for f in fans:
			if f[2]<8: continue
			var at=art_point(key,base,Vector2(f[0],f[1]))
			var radius=f[2]*draw_scale/1.5
			if running:
				# The painted fan is static: a darker rotating blade set reads as spin.
				for k in range(3):
					var angle=time*4+k*TAU/3
					draw_line(at,at+Vector2(cos(angle),sin(angle)*0.5)*radius*0.85,Color(0.1,0.17,0.19,0.6),maxf(1,radius*0.22))
				if lot.kind=="cooling" and tier<3:
					for k in range(2):
						var t=fmod(time*0.3+k*0.5+f[0]*0.01,1)
						art.ellipse(at+Vector2(t*10,-t*30)*draw_scale,Vector2(3+t*7,2+t*3.5),Color(0.89,0.96,0.86,(1-t)*0.3))
	if lot.kind in ["house","warehouse"] and meta.has("steam") and network.get("weather",{}).get("temperature",20)<16:
		for s in meta.steam:
			var at=art_point(key,base,Vector2(s[0],s[1]))
			for k in range(2):
				var t=fmod(time*0.25+k*0.5+s[0]*0.013,1)
				art.ellipse(at+Vector2(t*6,-t*18)*draw_scale,Vector2(2+t*4,1.5+t*2),Color(0.92,0.92,0.88,(1-t)*0.28))
	if lot.kind in Sim.BUILDINGS:
		var warning=""
		if int(lot.get("service_until",0))>sim.hour: warning="M %dh" % (int(lot.service_until)-sim.hour)
		elif lot.get("failed",false): warning="! FAILED"
		elif lot.get("condition",100)<55: warning="! %.0f%%" % lot.condition
		if not warning.is_empty():
			var at=Vector2(point(lot.x+0.5,lot.y+0.5).x,sprite_top(key,lot.x,lot.y)-4*draw_scale)
			draw_rect(Rect2(at-Vector2(24,12),Vector2(62,17)),Color("512f2c"))
			draw_string(font,at+Vector2(-20,0),warning,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ffe0a3"))
	var level=int(lot.get("level",1))
	if level>1:
		var accent=Color("8ccad8") if level==2 else Color("edd089")
		var at=point(lot.x+0.52,lot.y+0.90,32 if lot.kind=="datacenter" else 20)
		draw_rect(Rect2(at-Vector2(9,8)*draw_scale,Vector2(18,10)*draw_scale),Color("214d56"))
		draw_string(font,at+Vector2(-6,0)*draw_scale,"II" if level==2 else "III",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(8,int(10*draw_scale)),accent)

func vehicle_position(car:Dictionary) -> Vector2:
	var t=-2+car.at if car.dir==1 else 18-car.at
	var lane=float(car.get("road",4))+(0.34 if car.dir==1 else 0.67)
	return Vector2(t,lane) if car.axis==0 else Vector2(lane,t)

## Screen heading of a move along the map axes, as named by the vehicle sprites.
static func heading(axis:int,dir:int) -> String:
	if axis==0: return "se" if dir>0 else "nw"
	return "sw" if dir>0 else "ne"

func draw_vehicle(car:Dictionary) -> void:
	var pos=vehicle_position(car)
	var tint=OUTSIDE_TINT if outside_town(pos.x,pos.y) else Color.WHITE
	draw_art("%s_%s" % [car.get("model","car_hatch_a"),heading(car.axis,car.dir)],point(pos.x,pos.y),tint)

func draw_person(person:Dictionary) -> void:
	var at=point(person.pos.x,person.pos.y);var scale_factor=draw_scale
	var step=sin(person.phase)*2 if person.wait<=0 else 0.0
	var shirt=[Color("b75a56"),Color("5b88a0"),Color("f0d278"),Color("dfd6bc"),Color("9276a2"),Color("61965f"),Color("df9563"),Color("3f686c")][person.variant]
	draw_ellipse_at(at+Vector2(2,1)*scale_factor,Vector2(3,1.5)*scale_factor,Color(0.15,0.22,0.16,0.23))
	art.line(at+Vector2(-1,-5)*scale_factor,at+Vector2(-2+step,0)*scale_factor,Color("3d4c53"),2)
	art.line(at+Vector2(1,-5)*scale_factor,at+Vector2(2-step,0)*scale_factor,Color("3d4c53"),2)
	draw_rect(Rect2(at+Vector2(-2,-11)*scale_factor,Vector2(4,7)*scale_factor),shirt)
	draw_circle(at+Vector2(0,-14)*scale_factor,2.4*scale_factor,Color("e8bc8d"))
	draw_rect(Rect2(at+Vector2(-2,-16)*scale_factor,Vector2(4,2)*scale_factor),Color("72533c"))

func _draw() -> void:
	if sim==null or art==null: return
	network=sim.metrics();art.network=network
	crane_sites.clear()
	for job in sim.workforce.jobs:
		if job.kind in ["construction","upgrade"]: crane_sites[int(job.site)]=true
	var objects:Array=static_objects.duplicate()
	# Flow animates independently of the retained ground canvas.
	for lot in sim.lots:
		if lot.kind!="water": continue
		for k in range(2):
			var flow=fmod(time*0.15+k*0.5+lot.x*0.25,1)
			draw_line(point(lot.x+0.3,lot.y+flow),point(lot.x+0.6,lot.y+flow),Color(0.72,0.9,0.9,0.28*sin(flow*PI)),maxf(1,draw_scale))
	draw_overlays()
	draw_ground_markers()
	for person in pedestrians: objects.append({"depth":person.pos.x+person.pos.y,"type":"person","data":person})
	for car in vehicles.slice(0,visible_traffic()):
		var pos=vehicle_position(car);objects.append({"depth":pos.x+pos.y,"type":"car","data":car})
	for lot in sim.lots:
		if lot.kind=="grass" and lot.get("quiet",false): objects.append({"depth":lot.x+lot.y+1,"type":"barrier","data":lot})
	for job in sim.workforce.jobs:
		var pos=dispatch_position(job)
		objects.append({"depth":pos.x+pos.y,"type":"dispatch","data":job})
	for protest in protest_groups(): objects.append({"depth":protest.pos.x+protest.pos.y,"type":"protest","data":protest})
	for idx in anims:
		if anims[idx].type=="demolish":
			var site:Dictionary=sim.lots[idx]
			objects.append({"depth":site.x+site.y+1.25,"type":"demolition","data":idx})
	var ghost_index=hovered if tool in Sim.BUILDINGS and hovered>=0 and sim.lots[hovered].kind not in ["road","water"] else -1
	if ghost_index>=0:
		var g:Dictionary=sim.lots[ghost_index]
		objects.append({"depth":g.x+g.y+1.3,"type":"ghost","data":ghost_index})
	objects.sort_custom(func(a,b):return a.depth<b.depth)
	for obj in objects:
		match obj.type:
			"building": baked_building(obj.data)
			"prop": prop(obj.key,obj.x,obj.y,OUTSIDE_TINT if outside_town(obj.x,obj.y) else Color.WHITE)
			"person": draw_person(obj.data)
			"car": draw_vehicle(obj.data)
			"protest": draw_protest(obj.data)
			"barrier": draw_acoustic_barrier(obj.data)
			"dispatch": draw_dispatch(obj.data)
			"demolition": draw_demolition(sim.lots[obj.data],anims[obj.data],obj.data)
			"ghost": draw_ghost(obj.data)
	for junction in [Vector2(4,4),Vector2(12,4),Vector2(4,12),Vector2(12,12)]:
		for offset in [Vector2(0.08,-0.1),Vector2(1,0.1)]:
			var at=junction+offset;art.line(point(at.x,at.y),point(at.x,at.y,22),Color("485b4b"),2)
			var p=point(at.x,at.y,22)
			draw_rect(Rect2(p-Vector2(2,7)*draw_scale,Vector2(4,9)*draw_scale),Color("344b42"))
			draw_circle(p-Vector2(0,4)*draw_scale,1.5*draw_scale,Color("e2a46b") if fmod(time,16)<8 else Color("8bd287"))
	if network.weather.temperature>=35:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.94,0.45,0.13,0.08))
		for lot in sim.lots:
			if lot.kind!="datacenter": continue
			var at=point(lot.x+0.5,lot.y+0.5,80)
			for k in range(3):
				var t=fmod(time*0.5+k*0.33,1)
				draw_line(at+Vector2(-12+sin(t*TAU)*4,-t*20),at+Vector2(12+sin(t*TAU)*4,-t*20),Color(1,0.8,0.4,(1-t)*0.4),1)
	if network.weather.grid==0: draw_rect(Rect2(Vector2.ZERO,size),Color(0.03,0.08,0.18,0.12))
	# Only the floating marker sits above the scenery; the plot outlines are on the ground.
	if selected>=0 and selected<sim.lots.size():
		var lot:Dictionary=sim.lots[selected]
		var at=point(lot.x+0.5,lot.y+0.5,87+sin(time*3)*2)
		if lot.kind not in ["grass","road","water"]: at.y=sprite_top(building_key(lot),lot.x,lot.y)-(10+sin(time*3)*2)*draw_scale
		polygon([at+Vector2(-5,-5),at+Vector2(5,-5),at+Vector2(0,2)],Color("fff1a5"))
	for e in effects:
		var at=point(e.x+0.5,e.y+0.5)
		for k in range(16):
			var a=k*2.399;var t=1.5-e.life
			draw_circle(at+Vector2(cos(a)*t*35,sin(a)*t*18-t*20)*draw_scale,(3+t*5)*draw_scale,Color(0.87,0.84,0.69,e.life/2))
	for i in range(16):
		draw_rect(Rect2(0,i*12,size.x,12),Color(0.07,0.15,0.12,0.65*(1-i/16.0)))
		draw_rect(Rect2(0,size.y-(i+1)*12,size.x,12),Color(0.07,0.15,0.12,0.65*(1-i/16.0)))
	var census="%d residents · %d jobs · %d walkers · hover a walker to hear their thoughts" % [town_population(),town_jobs(),pedestrians.size()]
	var census_at=Vector2(play_area.position.x,play_area.end.y-12)
	draw_string(font,census_at+Vector2(1,1),census,HORIZONTAL_ALIGNMENT_RIGHT,play_area.size.x-12,12,Color(0,0,0,0.6))
	draw_string(font,census_at,census,HORIZONTAL_ALIGNMENT_RIGHT,play_area.size.x-12,12,Color("eef0d5"))
	draw_cost_tag()

func draw_cost_tag() -> void:
	if tool=="inspect" or hovered<0 or not cost_tag.is_valid() or not play_area.has_point(mouse_position): return
	var tag:Dictionary=cost_tag.call(hovered)
	if tag.is_empty(): return
	var tones={"ok":Color("a5dfbc"),"warn":Color("e4ca8b"),"bad":Color("ef8a6f")}
	var color:Color=tones.get(tag.tone,Color.WHITE)
	var font_size=roundi(14*text_scale)
	var extent=font.get_string_size(tag.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var box=Rect2(mouse_position+Vector2(18,20),extent+Vector2(20,12))
	if box.end.x>play_area.end.x: box.position.x=mouse_position.x-box.size.x-12
	if box.end.y>play_area.end.y: box.position.y=mouse_position.y-box.size.y-12
	var pill=StyleBoxFlat.new();pill.bg_color=Color(0.05,0.12,0.11,0.94);pill.border_color=color
	pill.set_border_width_all(1);pill.set_corner_radius_all(6)
	pill.shadow_color=Color(0,0,0,0.35);pill.shadow_size=6
	draw_style_box(pill,box)
	draw_string(font,box.position+Vector2(10,6+font.get_ascent(font_size)),tag.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

## Plot outlines and placement footprints drawn at ground level, before any
## building, tree or person, so tall buildings correctly cover them.
## Semi-transparent preview of the selected building on the plot under the cursor:
## mint when it can be built, coral when it cannot.
func draw_ghost(index:int) -> void:
	var lot:Dictionary=sim.lots[index]
	var ok:bool=ghost_valid.call(index) if ghost_valid.is_valid() else (lot.owned and lot.kind=="grass")
	var tint=Color(0.75,1.0,0.86,0.58) if ok else Color(1.0,0.55,0.48,0.5)
	var pulse=0.0 if reduced_motion else sin(real_time*4)*0.06
	tint.a+=pulse
	sprite(ghost_key(lot),lot.x,lot.y,tint)

func draw_ground_markers() -> void:
	var limits=[point(0,0),point(TOWN_SIZE,0),point(TOWN_SIZE,TOWN_SIZE),point(0,TOWN_SIZE)]
	outline(limits,Color(0.05,0.12,0.1,0.55),4*draw_scale)
	outline(limits,Color(0.97,0.93,0.67,0.85),1.5*draw_scale)
	if selected>=0 and selected<sim.lots.size():
		var lot:Dictionary=sim.lots[selected]
		polygon(diamond(lot.x,lot.y,0.04,1),Color(1,0.95,0.65,0.18))
		outline(diamond(lot.x,lot.y,0.01,1),Color("fff1a5"),2.2*draw_scale)
	if hovered>=0:
		var lot:Dictionary=sim.lots[hovered]
		outline(diamond(lot.x,lot.y,0.02,1),Color("e5eed0"),2*draw_scale)
		if tool in Sim.BUILDINGS: draw_placement(lot)

func draw_placement(lot:Dictionary) -> void:
	var preview=sim.site_preview(Sim.cell(int(lot.x),int(lot.y)),tool,build_profile)
	var valid=lot.owned and lot.kind=="grass" and not preview.protected and preview.permit_error.is_empty()
	var tint=Color("a5dfbc") if valid else Color("ecb27f")
	outline(diamond(lot.x,lot.y,0.1,40),tint,2)
	for corner in [Vector2(0.1,0.1),Vector2(0.9,0.1),Vector2(0.9,0.9),Vector2(0.1,0.9)]:
		draw_line(point(lot.x+corner.x,lot.y+corner.y),point(lot.x+corner.x,lot.y+corner.y,40),tint,1)
	if tool=="datacenter":
		for target in [preview.power_lot,preview.cooling_lot]:
			if target>=0:
				var utility:Dictionary=sim.lots[target]
				draw_dashed_line(point(lot.x+0.5,lot.y+0.5,5),point(utility.x+0.5,utility.y+0.5,5),tint,2,5)

func draw_overlays() -> void:
	if overlay=="Town view": return
	var key="%s:%s:%s" % [overlay,sim.hour,sim.cash]
	if key!=overlay_key:
		overlay_key=key;overlay_cells.clear()
		for lot in sim.lots:
			var mark="";var color=Color(0.2,0.3,0.25,0.35)
			match overlay:
				"Electricity","Cooling":
					var covered=not (sim.utility_for(lot,"power") if overlay=="Electricity" else sim.cooling_for(lot)).is_empty()
					if covered: color=Color(0.9,0.75,0.3,0.45) if overlay=="Electricity" else Color(0.3,0.65,0.9,0.45)
					mark=("P" if overlay=="Electricity" else "C") if covered else "×"
				"Noise","Opinion":
					var pressure=Sim.Civic.local_noise(sim,lot)
					var value=pressure if overlay=="Noise" else clampf(sim.civic.wards[Sim.Civic.ward_for(lot)].opinion-(pressure-sim.civic_reports[Sim.Civic.ward_for(lot)].noise)*0.2,0,100)
					var good=1.0-value/100.0 if overlay=="Noise" else value/100.0
					color=Color(0.8,0.35,0.2,0.55).lerp(Color(0.3,0.75,0.5,0.45),good);mark=str(roundi(value))
				"Ownership":
					mark="Y" if lot.owned else ("!" if lot.get("protected",false) else ("—" if lot.kind in ["road","water"] else "$"))
					color=Color(0.4,0.85,0.6,0.45) if lot.owned else Color(0.8,0.65,0.3,0.4)
			overlay_cells.append({"lot":lot,"mark":mark,"color":color})
	for item in overlay_cells:
		var lot=item.lot;polygon(diamond(lot.x,lot.y,0.02,1),item.color)
		draw_string(font,point(lot.x+0.15,lot.y+0.8,2),item.mark,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(9,int(13*draw_scale)),Color("fff6cf"))

func bubble_style() -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=Color("2b473c");style.set_corner_radius_all(4);return style

func update_hover() -> void:
	hovered=pick(mouse_position);hovered_person=-1
	for i in range(pedestrians.size()):
		var person=pedestrians[i]
		if point(person.pos.x,person.pos.y,7).distance_to(mouse_position)<8*draw_scale: hovered_person=i;break

func _gui_input(event:InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_position=event.position
		if dragging: pan+=event.relative
		update_camera();update_hover()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE: dragging=event.pressed
		if not event.pressed: return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var before=world(event.position)
			zoom=clampf(zoom*(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.12),0.65,2.4)
			update_camera();pan+=event.position-point(before.x,before.y);update_camera()
		if event.button_index==MOUSE_BUTTON_LEFT:
			var index=pick(event.position)
			if index>=0: selected=index;lot_selected.emit(index);lot_activated.emit(index)
		if event.button_index==MOUSE_BUTTON_RIGHT: tool="inspect";lot_selected.emit(selected)

func dust(index:int) -> void:
	var lot:Dictionary=sim.lots[index];effects.append({"x":lot.x,"y":lot.y,"life":1.5})

func draw_ground(x:int,y:int,lot:Dictionary={}) -> void:
	# Source recipe used by bake_art.gd. Live rendering uses the resulting atlas.
	var color=Color("83a95a").lightened(noise_at(x,y)*0.07)
	if lot.get("owned",false): color=Color("92ad67")
	polygon(diamond(x,y,0),color)
	for k in range(12):
		var p=point(x+noise_at(x,y,k+1),y+noise_at(y,x,k+28))
		draw_rect(Rect2(p,Vector2(2,1)*draw_scale),Color("a9bd75") if k%3==0 else Color("759951"))
	if not lot.is_empty() and lot.kind!="road":
		art.ground(x,y,1,0.065,Color("c5bd94"));art.ground(x,y,0.065,1,Color("c5bd94"))
	if x==4 or y==4:
		polygon(diamond(x,y,0),Color("bcbba7"))
		if x==4: art.ground(x+0.17,y,0.66,1,Color("6d746d"))
		if y==4: art.ground(x,y+0.17,1,0.66,Color("6d746d"))
		if x!=4: art.line(point(x+0.28,y+0.5),point(x+0.68,y+0.5),Color("d3c78c"))
		if y!=4: art.line(point(x+0.5,y+0.28),point(x+0.5,y+0.68),Color("d3c78c"))
		if x==4 and y in [3,5]:
			for k in range(5): art.ground(x+0.22+k*0.12,y+(0.82 if y==3 else 0.05),0.065,0.13,Color("e2ddc0"))
		if y==4 and x in [3,5]:
			for k in range(5): art.ground(x+(0.82 if x==3 else 0.05),y+0.22+k*0.12,0.13,0.065,Color("e2ddc0"))
		for k in range(4):
			if x==4: art.line(point(x,y+k*0.25),point(x+0.15,y+k*0.25),Color("a1a48f"))
			if y==4: art.line(point(x+k*0.25,y),point(x+k*0.25,y+0.15),Color("a1a48f"))
	if lot.get("owned",false): outline(diamond(x,y,0.015),Color(0.90,0.93,0.62,0.55),maxf(1,draw_scale))

func town_population() -> int:
	var total=0
	for row in sim.civic_reports.values(): total+=int(row.population)
	return total

func town_jobs() -> int:
	var total=0
	for row in sim.civic_reports.values(): total+=int(row.jobs)
	return total

func protest_groups() -> Array:
	var groups=[]
	for id in sim.civic.wards:
		if sim.civic.wards[id].stage<3: continue
		var anchor:Dictionary={}
		for lot in sim.lots:
			if Sim.Civic.ward_for(lot)==id and lot.kind in ["park","monument"]: anchor=lot;break
		if anchor.is_empty():
			for lot in sim.lots:
				if Sim.Civic.ward_for(lot)==id and lot.kind=="road": anchor=lot;break
		if not anchor.is_empty(): groups.append({"pos":Vector2(anchor.x+0.5,anchor.y+0.5),"ward":id})
	return groups

func draw_protest(group:Dictionary) -> void:
	for i in range(8):
		var pos:Vector2=group.pos+Vector2((i%4)*0.18-0.25,(i/4)*0.20+sin(time*2+i)*0.025)
		var at=point(pos.x,pos.y,0)
		draw_circle(at-Vector2(0,11)*draw_scale,2.5*draw_scale,Color("efc49e"))
		draw_line(at-Vector2(0,8)*draw_scale,at-Vector2(0,2)*draw_scale,Color("edbb74") if i%2==0 else Color("94cbb8"),4*draw_scale)
		if i%2==0:
			draw_line(at+Vector2(3,-6)*draw_scale,at+Vector2(3,-24)*draw_scale,Color("e0c798"),draw_scale)
			draw_rect(Rect2(at+Vector2(-4,-28)*draw_scale,Vector2(15,8)*draw_scale),Color("fff0c9"))
			draw_line(at+Vector2(-1,-25)*draw_scale,at+Vector2(8,-25)*draw_scale,Color("a14834"),draw_scale)
	var title=point(group.pos.x,group.pos.y,42)
	draw_string(font,title+Vector2(-65,0),"RESIDENTS / "+Sim.Civic.STAGES[int(sim.civic.wards[group.ward].stage)].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("fff0c9"))

func visible_traffic() -> int:
	var trips=0.0
	for row in sim.civic_reports.values(): trips+=row.trips
	return clampi(8+ceili(trips/2),8,vehicles.size())

func thought_bounds(anchor:Vector2,extent:Vector2) -> Rect2:
	var safe=play_area.grow(-8)
	var bottom=safe.end.y
	safe.position.y=maxf(safe.position.y,280)
	safe.size.y=bottom-safe.position.y
	var top_left=anchor-Vector2(extent.x/2,extent.y+24)
	top_left.x=clampf(top_left.x,safe.position.x,maxf(safe.position.x,safe.end.x-extent.x))
	top_left.y=clampf(top_left.y,safe.position.y,maxf(safe.position.y,safe.end.y-extent.y))
	return Rect2(top_left,extent)

func update_thought() -> void:
	if thought_panel==null: return
	thought_panel.visible=hovered_person>=0
	if hovered_person<0: return
	var person:Dictionary=pedestrians[hovered_person]
	var id=Sim.Geography.district(clampi(int(person.pos.x),0,15),clampi(int(person.pos.y),0,15))
	thought_label.add_theme_font_size_override("font_size",roundi(16*text_scale))
	thought_label.text=person.name+" / "+Sim.Geography.DISTRICTS[id].name+"\n"+person.get("purpose","Walking through town")+". "+Sim.Civic.thought(sim,id)
	thought_panel.reset_size()
	thought_panel.position=thought_bounds(point(person.pos.x,person.pos.y,30),thought_panel.size).position

func draw_acoustic_barrier(lot:Dictionary) -> void:
	art.box(lot.x+0.05,lot.y+0.9,0.9,0.05,16,Color("668878"))
	art.box(lot.x+0.9,lot.y+0.1,0.05,0.8,16,Color("668878"))

func resident_destination(person:Dictionary) -> Dictionary:
	var homes=sim.lots.filter(func(lot):return lot.kind=="house")
	var resident:int=person.get("resident_id",0)
	var home:Dictionary=homes[resident%homes.size()] if not homes.is_empty() else sim.lots[68]
	var ward:String=home.district
	var candidates=[]
	var purpose="Heading home"
	var clock=sim.hour%24
	if sim.civic.wards[ward].stage>=3 and resident%3==0:
		candidates=sim.lots.filter(func(lot):return lot.district==ward and lot.kind in ["park","monument"])
		purpose="Joining the neighborhood demonstration"
	elif sim.Research.campaign_active(sim,ward) and clock>=10 and clock<18:
		candidates=sim.lots.filter(func(lot):return lot.district==ward and lot.kind in ["park","monument","datacenter"])
		purpose="Visiting the AI open day"
	elif clock>=7 and clock<17:
		candidates=sim.lots.filter(func(lot):return lot.kind in sim.BUILDINGS or (lot.district=="market" and lot.kind=="house"))
		purpose="On the way to work" if resident%2==0 else "Shopping in town"
	elif clock>=17 and clock<21:
		candidates=sim.lots.filter(func(lot):return lot.kind=="park")
		purpose="Taking an evening walk in the park"
	var target:Dictionary=home if candidates.is_empty() else candidates[resident%candidates.size()]
	return {"site":Sim.cell(int(target.x),int(target.y)),"purpose":"Heading home" if candidates.is_empty() else purpose}

func dispatch_position(job:Dictionary) -> Vector2:
	var lot:Dictionary=sim.lots[int(job.site)]
	var site=Vector2(lot.x+0.5,lot.y+0.88)
	var road_x=12.55 if lot.x>=10 else 4.55
	var entry=Vector2(road_x,0.5)
	var junction=Vector2(road_x,4.55 if lot.x in [8,9] else lot.y+0.5)
	var progress=clampf((sim.hour+work_fraction-job.start)/maxf(1,job.end-job.start),0,1)
	# Most of each visit is spent at the site. The initial road journey explains its arrival.
	if progress<0.14: return entry.lerp(junction,progress/0.14)
	if progress<0.25: return junction.lerp(site,(progress-0.14)/0.11)
	return site

func draw_dispatch(job:Dictionary) -> void:
	var pos=dispatch_position(job)
	var repair=job.kind in ["repair","service"]
	var progress=clampf((sim.hour+work_fraction-job.start)/maxf(1,job.end-job.start),0,1)
	var lot:Dictionary=sim.lots[int(job.site)]
	var facing="sw" if progress<0.14 else ("se" if lot.x+0.5>=pos.x else "nw")
	draw_art(("van_maintenance_" if repair else "truck_box_")+facing,point(pos.x,pos.y))
	var at=point(pos.x,pos.y,30)
	draw_string(font,at-Vector2(4,0),"+" if repair else "D",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(10,int(13*draw_scale)),Color("fff2c4"))
	if sim.hour+work_fraction-job.start>0.25*(job.end-job.start):
		var worker={"pos":pos+Vector2(-0.22,-0.22),"phase":time*5,"wait":0,"variant":2}
		draw_person(worker)
		art.box(pos.x-0.35,pos.y+0.05,0.12,0.10,7,Color("b97951"))

func reset_residents() -> void:
	for person in pedestrians:
		var target=resident_destination(person)
		var lot:Dictionary=sim.lots[target.site]
		person.pos=Vector2(lot.x+0.06,lot.y+0.06);person.goal=person.pos
		person.route=[];person.wait=1.0;person.destination=target.site;person.purpose=target.purpose

func draw_construction(job:Dictionary) -> void:
	if job.kind not in ["construction","upgrade"]: return
	var lot:Dictionary=sim.lots[int(job.site)]
	draw_crane(lot,1.0,0.5+sin(time*0.8)*0.5)
