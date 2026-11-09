extends SceneTree
## The painted town sprite set (assets/town_art.json) covers everything the map draws:
## every authored building in every town, campus states, ground, river, roads, vehicles
## and construction. Isolated QA saves only.
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=0

func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_art.json"))
	expect(data!=null and data.sprites.size()==263,"All 263 delivered sprites are packed")
	for path in data.pages: expect(load(path) is Texture2D,"Texture page loads: "+path)
	var view=load("res://scripts/town_view.gd").new()
	var s=Sim.new();view.sim=s;root.add_child(view)
	await process_frame
	expect(view.sprites.has("hall_balanced_t1_on") and view.sprites.hall_balanced_t1_on.rect.size.x<256,"Painted sprites load trimmed, with their offsets")
	expect(view.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"Town view draws the painted art with mipmaps")
	# Campus: every hardware, tier and state.
	var missing:Array=[]
	for profile in ["balanced","efficient","refurbished","training"]:
		for tier in [1,2,3]:
			var lot={"kind":"datacenter","x":3,"y":5,"level":tier,"hardware":profile,"district":"oldtown","town":"littlebrook"}
			for online in [false,true]:
				view.network={"efficiency":1.0 if online else 0.0,"power":100 if online else 0,"disconnected":[],"refitting":[]}
				var key=view.building_key(lot)
				if not view.sprites.has(key): missing.append(key)
	for kind in ["power","cooling"]:
		for tier in [1,2,3]:
			for online in [false,true]:
				view.network={"efficiency":1.0,"power":100 if online else 0}
				var key=view.building_key({"kind":kind,"x":7,"y":5,"level":tier,"district":"riverside","town":"littlebrook"})
				if not view.sprites.has(key): missing.append(key)
	view.network={"efficiency":1.0,"power":100,"disconnected":[],"refitting":[]}
	expect(view.building_key({"kind":"cooling","x":7,"y":5,"level":1,"district":"riverside","town":"littlebrook"})=="cooling_riverfront_t1_on","Riverside cooling uses the river intake plant")
	expect(view.building_key({"kind":"datacenter","x":3,"y":5,"level":1,"hardware":"training","district":"oldtown","town":"littlebrook"}).begins_with("hall_training_t2"),"Tier-1 training hall uses the smallest training shell")
	view.network={}
	expect(view.building_key({"kind":"datacenter","x":3,"y":5,"level":2,"hardware":"efficient","district":"oldtown","town":"littlebrook"})=="hall_efficient_t2_off","Halls without a network are drawn dark")
	# Every authored lot in every town has a painted building and ground tile.
	var kinds:Dictionary={}
	for town in ["littlebrook","sunsprawl","oldbridge"]:
		s.new_game("Art QA",town)
		view.sim=s
		for lot in s.lots:
			if lot.kind not in ["grass","road","water"]:
				var key=view.building_key(lot);kinds[key]=true
				if not view.sprites.has(key): missing.append(town+":"+key)
		for y in range(-6,22):
			for x in range(-6,22):
				for key in [view.terrain_key(x,y),view.countryside_key(x,y)]:
					if not view.sprites.has(key): missing.append(town+":"+key)
		for tool in ["datacenter","power","cooling"]:
			view.tool=tool
			for profile in ["balanced","efficient","refurbished","training"]:
				view.build_profile=profile
				var key=view.ghost_key(s.lots[83])
				if not view.sprites.has(key): missing.append("ghost:"+key)
	expect(kinds.size()>=30,"The towns use a wide variety of buildings (%d distinct)" % kinds.size())
	s.new_game("Art QA","littlebrook")
	expect(view.building_key(s.lots[Sim.cell(7,2)])=="landmark_clock_tower","Littlebrook's monument is the clock tower")
	expect(view.building_key(s.lots[Sim.cell(3,5)])=="ind_warehouse_0","The conversion site is a for-sale warehouse")
	# Vehicles in every heading, river, roads, construction and props.
	for car in view.vehicles:
		for axis in [0,1]:
			for dir in [-1,1]:
				var key="%s_%s" % [car.model,view.heading(axis,dir)]
				if not view.sprites.has(key): missing.append(key)
	for key in ["water_bank_nw","water_bank_se","bridge_road_x","bridge_stone_arch_x","junction_0","crossing_x","crossing_y","road_bus_stop_x","road_x_0","road_y_1",
		"site_foundation","site_frame_low","site_frame_high","site_crane","rubble_0","rubble_1","power_battery_module","power_generator_module",
		"street_lamp_classic","street_lamp_modern","lot_owned"]+view.RIVER_PROPS.values()+view.COUNTRY_PROPS.values():
		if not view.sprites.has(key): missing.append(key)
	expect(missing.is_empty(),"Every drawn key has a painted sprite. Missing: "+str(missing))
	expect(view.sprites.site_crane.meta.has("hook"),"Crane hook anchor is available for the swinging load")
	expect(view.sprites.hall_training_t2_on.meta.fans.size()==6,"Fan anchors are available for spinning blades")
	view.queue_free()
	print("TOWN ART: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
