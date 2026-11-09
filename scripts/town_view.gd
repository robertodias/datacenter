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

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	art=Art.new(self)
	var atlas=load("res://assets/town_atlas.png")
	var regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_atlas.json"))
	for key in regions:
		var tex=AtlasTexture.new();tex.atlas=atlas
		var r=regions[key];tex.region=Rect2(r[0],r[1],r[2],r[3]);sprites[key]=tex
	ground_canvas=load("res://scripts/town_ground.gd").new()
	ground_canvas.parent_view=self;ground_canvas.z_index=-1
	add_child(ground_canvas)
	rng.seed=12275
	for i in range(48):
		var pos=Vector2(rng.randi_range(0,7)+0.06,rng.randi_range(0,15)+0.06)
		pedestrians.append({"pos":pos,"goal":pos,"route":[],"wait":rng.randf_range(0,4),"pace":rng.randf_range(0.18,0.28),"phase":rng.randf()*TAU,"variant":i%8,"resident_id":i,"purpose":"Heading home","destination":-1,"name":["Maya","Leo","Nora","Oliver","Ana","Sam","Iris","Ben"][i%8]})
	for i in range(16):
		vehicles.append({"at":float(i)*1.35,"axis":i%2,"dir":1 if i%4<2 else -1,"type":i%5,"pace":0.50 if i%5==0 else 0.72,"road":4 if i<10 else 12})
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
	var key="%s:%s:%s:%s" % [origin,draw_scale,size,sim.cash if sim!=null else 0]
	if ground_canvas!=null and key!=ground_key:
		ground_key=key;ground_canvas.queue_redraw()

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

func sprite(key:String,x:float,y:float,tint:Color=Color.WHITE) -> void:
	if not sprites.has(key): return
	var factor=draw_scale/1.5
	draw_texture_rect(sprites[key],Rect2(point(x,y)-Vector2(128,136)*factor,Vector2(256,256)*factor),false,tint)

func baked_ground(x:int,y:int,lot:Dictionary) -> void:
	if lot.get("kind","")=="water":
		polygon(diamond(x,y,0),Color("629da4"))
		for k in range(3):
			var flow=fmod(time*0.15+k*0.33,1)
			art.line(point(x+0.2,y+flow),point(x+0.65,y+flow),Color("8dc7ca"))
		return
	var key="grass_"+str(posmod(x+y,3))
	if not lot.is_empty(): key="lot_"+str(lot.owned)
	var road_x=x in [4,12];var road_y=y in [4,12]
	if road_x and road_y: key="junction"
	elif road_x: key="cross_v"+str(y) if x==4 and y in [3,5] else "road_v"
	elif road_y: key="cross_h"+str(x) if y==4 and x in [3,5] else "road_h"
	sprite(key,x,y,Color("edcf9e") if sim!=null and sim.scenario_id=="sunsprawl" else Color.WHITE)
	if lot.get("protected",false): outline(diamond(x,y,0.04),Color(0.95,0.85,0.5,0.7),1)
	if x in [8,9] and road_y:
		art.fence(x,y+0.05,1,0);art.fence(x,y+0.95,1,0)

func baked_building(lot:Dictionary) -> void:
	var key:String=lot.kind
	var tier=int(lot.get("level",1))
	if key=="house":
		var variant=posmod(int(lot.x*7+lot.y*3),5)
		var shop=(int(lot.x)==3 or int(lot.y)==3 or Sim.Geography.district(int(lot.x),int(lot.y))=="market") and variant<3
		key="house_%d_%s" % [variant,str(shop)]
		if not sprites.has(key): key="house_0_false"
		if sim.scenario_id=="sunsprawl": key="family_%d" % (3 if lot.district=="market" else posmod(int(lot.x+lot.y),2))
		elif sim.scenario_id=="oldbridge": key="family_%d" % [2+posmod(int(lot.x*3+lot.y),4)]
		elif posmod(int(lot.x+lot.y),3)==0: key="family_%d" % posmod(int(lot.x*3+lot.y),6)
	if key=="datacenter" and network.efficiency>0 and not Sim.cell(int(lot.x),int(lot.y)) in network.disconnected and not Sim.cell(int(lot.x),int(lot.y)) in network.refitting and Sim.Operations.available(lot,sim.hour): key="datacenter_on"
	if lot.kind in Sim.BUILDINGS and tier>1:
		var online=network.efficiency>0 and Sim.Operations.available(lot,sim.hour) and int(lot.get("refit_until",0))<=sim.hour and not Sim.cell(int(lot.x),int(lot.y)) in network.disconnected
		key="%s_t%d_%s" % [lot.kind,tier,str(online)]
	sprite(key,lot.x,lot.y)
	if lot.get("quiet",false): draw_acoustic_barrier(lot)
	if lot.kind in ["cooling","datacenter"]:
		var running=network.power>0 and Sim.Operations.available(lot,sim.hour) and int(lot.get("refit_until",0))<=sim.hour
		var fans=[Vector3(0.31,0.49,37),Vector3(0.67,0.49,37)] if lot.kind=="cooling" else [Vector3(0.265,0.3,60),Vector3(0.495,0.3,60),Vector3(0.725,0.3,60),Vector3(0.265,0.59,60),Vector3(0.495,0.59,60),Vector3(0.725,0.59,60)]
		if tier>1:
			if lot.kind=="cooling": fans=[Vector3(0.28,0.29,25 if tier==2 else 46),Vector3(0.28,0.59,25 if tier==2 else 46),Vector3(0.71,0.29,25 if tier==2 else 46),Vector3(0.71,0.59,25 if tier==2 else 46)]
			elif tier==2: fans=[Vector3(0.26,0.32,64),Vector3(0.26,0.58,64)]
			else: fans=[Vector3(0.27,0.26,83),Vector3(0.48,0.26,83),Vector3(0.27,0.5,83),Vector3(0.48,0.5,83)]
		for f in fans:
			var at=point(lot.x+f.x,lot.y+f.y,f.z);var radius=9 if lot.kind=="cooling" else 4
			art.ellipse(at,Vector2(radius,radius*0.5),Color("375864"))
			for k in range(4):
				var angle=(time*3 if running else 0.0)+k*TAU/4
				art.line(at,at+Vector2(cos(angle)*radius,sin(angle)*radius*0.5)*draw_scale,Color("9db7a7"))
			if lot.kind=="cooling" and running and tier<3:
				for k in range(3):
					var t=fmod(time*0.3+k*0.33,1)
					art.ellipse(at+Vector2(t*17,-t*34)*draw_scale,Vector2(3+t*8,2+t*4),Color(0.89,0.96,0.86,(1-t)*0.32))
	if lot.kind=="datacenter":
		var profile:String=lot.get("hardware","balanced")
		if tier>1:
			var color={"balanced":Color("a5bfc5"),"efficient":Color("65c6b2"),"refurbished":Color("c7a779"),"training":Color("d89573")}[profile]
			art.box(lot.x+0.77,lot.y+0.87,0.15,0.08,9,color,4)
		elif profile=="efficient":
			art.box(lot.x+0.12,lot.y+0.12,0.68,0.16,3,Color("358f9a"),52)
		elif profile=="refurbished":
			art.box(lot.x+0.1,lot.y+0.6,0.2,0.16,12,Color("a18a6c"),51)
		elif profile=="training":
			art.box(lot.x+0.12,lot.y+0.68,0.66,0.13,14,Color("c07c53"),51)
	if lot.kind in Sim.BUILDINGS:
		var idx=Sim.cell(int(lot.x),int(lot.y))
		var warning=""
		if int(lot.get("service_until",0))>sim.hour: warning="M %dh" % (int(lot.service_until)-sim.hour)
		elif lot.get("failed",false): warning="! FAILED"
		elif lot.get("condition",100)<55: warning="! %.0f%%" % lot.condition
		if not warning.is_empty():
			var at=point(lot.x+0.5,lot.y+0.5,83)
			draw_rect(Rect2(at-Vector2(24,12),Vector2(62,17)),Color("512f2c"))
			draw_string(font,at+Vector2(-20,0),warning,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ffe0a3"))
		if lot.kind=="power" and sim.ops.hub==idx:
			for i in range(int(sim.ops.batteries)):
				art.box(lot.x+0.08+i*0.19,lot.y+0.7,0.14,0.14,16,Color("79bdac") if sim.ops.charge>0 else Color("637a73"))
			for i in range(int(sim.ops.generators)):
				art.box(lot.x+0.08+i*0.19,lot.y+0.14,0.14,0.18,17,Color("c49855"))
				if network.generator_output>0:
					var t=fmod(time*0.45+i*0.33,1)
					art.ellipse(point(lot.x+0.14+i*0.19,lot.y+0.2,22+t*20),Vector2(4+t*4,2+t*2),Color(0.4,0.45,0.4,(1-t)*0.7))
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

func draw_vehicle(car:Dictionary) -> void:
	var pos=vehicle_position(car);var length=0.48 if car.type==0 else (0.38 if car.type==1 else 0.27)
	var w=length if car.axis==0 else 0.16;var d=0.16 if car.axis==0 else length
	var x=pos.x-w/2;var y=pos.y-d/2
	var color=[Color("d4a949"),Color("dcddd0"),Color("b55745"),Color("5d91a1"),Color("849356")][car.type]
	art.ground(x+0.035,y+0.035,w,d,Color(0.15,0.22,0.16,0.3))
	box(x,y,w,d,6,color,2);box(x+w*0.2,y+d*0.18,w*0.62,d*0.65,5,color.lightened(0.2),8)
	art.front(x+w*0.24,y+d*0.85,w*0.5,9,12,Color("416678"));art.side(x+w*0.83,y+d*0.25,d*0.48,9,12,Color("6799a6"))
	for at in [Vector2(x+w*0.18,y+d),Vector2(x+w*0.82,y+d)]:
		draw_circle(point(at.x,at.y,2),2.7*draw_scale,Color("35443c"));draw_circle(point(at.x,at.y,2),draw_scale,Color("b1b4a3"))
	if car.type==0:
		for k in range(4): art.front(x+w*(0.12+k*0.2),y+d*0.9,w*0.12,8,12,Color("385b68"))
	if car.type==1: box(x+w*0.1,y+d*0.05,w*0.6,d*0.75,7,Color("ebddbf"),8)

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
	var objects:Array=static_objects.duplicate()
	# Flow animates independently of the retained ground canvas.
	for lot in sim.lots:
		if lot.kind!="water": continue
		for k in range(2):
			var flow=fmod(time*0.15+k*0.5,1)
			art.line(point(lot.x+0.2,lot.y+flow),point(lot.x+0.65,lot.y+flow),Color("8dc7ca"))
	draw_overlays()
	for person in pedestrians: objects.append({"depth":person.pos.x+person.pos.y,"type":"person","data":person})
	for car in vehicles.slice(0,visible_traffic()):
		var pos=vehicle_position(car);objects.append({"depth":pos.x+pos.y,"type":"car","data":car})
	for lot in sim.lots:
		if lot.kind=="grass" and lot.get("quiet",false): objects.append({"depth":lot.x+lot.y+1,"type":"barrier","data":lot})
	for job in sim.workforce.jobs:
		var pos=dispatch_position(job)
		objects.append({"depth":pos.x+pos.y,"type":"dispatch","data":job})
	for protest in protest_groups(): objects.append({"depth":protest.pos.x+protest.pos.y,"type":"protest","data":protest})
	objects.sort_custom(func(a,b):return a.depth<b.depth)
	for obj in objects:
		match obj.type:
			"building": baked_building(obj.data)
			"tree": sprite("tree_"+str(posmod(obj.variant,4)),obj.x,obj.y)
			"lamp": sprite("lamp",obj.x,obj.y)
			"person": draw_person(obj.data)
			"car": draw_vehicle(obj.data)
			"protest": draw_protest(obj.data)
			"barrier": draw_acoustic_barrier(obj.data)
			"dispatch": draw_dispatch(obj.data)
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
	outline([point(0,0),point(16,0),point(16,16),point(0,16)],Color(0.97,0.93,0.67,0.6),1)
	if hovered>=0:
		var lot:Dictionary=sim.lots[hovered]
		outline(diamond(lot.x,lot.y,0.02,2),Color("e5eed0"),2*draw_scale)
		if tool in Sim.BUILDINGS: draw_placement(lot)
	if selected>=0 and selected<sim.lots.size():
		var lot:Dictionary=sim.lots[selected];outline(diamond(lot.x,lot.y,0.01,2),Color("fff1a5"),2.2*draw_scale)
		var at=point(lot.x+0.5,lot.y+0.5,87+sin(time*3)*2)
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
	draw_construction(job)
	var pos=dispatch_position(job)
	var repair=job.kind in ["repair","service"]
	var color=Color("e7c66f") if repair else Color("b8d4dc")
	box(pos.x-0.22,pos.y-0.09,0.44,0.18,8,color,2)
	box(pos.x-0.12,pos.y-0.07,0.20,0.14,5,color.lightened(0.2),10)
	art.front(pos.x-0.1,pos.y+0.08,0.17,12,15,Color("385663"))
	for offset in [-0.15,0.15]: draw_circle(point(pos.x+offset,pos.y+0.1,2),2.3*draw_scale,Color("263c3b"))
	var at=point(pos.x,pos.y,21)
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
	var x:float=lot.x;var y:float=lot.y
	var pulse=sin(time*2)*0.035
	art.line(point(x+0.05,y+0.08),point(x+0.05,y+0.08,90),Color("c9a653"),3)
	art.line(point(x+0.05,y+0.08,88),point(x+0.7+pulse,y+0.08,88),Color("e5ca7e"),3)
	art.line(point(x+0.62+pulse,y+0.08,88),point(x+0.62+pulse,y+0.08,64),Color("4e6261"))
	art.box(x+0.58+pulse,y+0.04,0.1,0.1,7,Color("b39063"),57)
