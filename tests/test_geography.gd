extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Geo=preload("res://scripts/town_rules.gd")
var checks=0
var failures=0
var path="user://geography-test.json"

func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)

func build_at(s,x:int,y:int,kind:String) -> int:
	var i=Sim.cell(x,y)
	s.buy(i)
	if s.lots[i].kind!="grass": s.demolish(i)
	expect(s.build(i,kind)=="","Build %s at %d,%d" % [kind,x,y])
	return i

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s=Sim.new()
	expect(s.lots.size()==256,"Expanded authored town")
	var areas:Dictionary={}
	for lot in s.lots: areas[lot.district]=true
	expect(areas.size()==5,"Five distinct neighborhoods")
	expect(s.lot_at(8,3).kind=="water" and s.lot_at(8,4).kind=="road","River and public bridge")
	expect(s.buy(Sim.cell(8,3))!="","River cannot be purchased")
	expect(s.buy(Sim.cell(12,7))!="","New public corridor cannot be purchased")
	expect(Geo.sensitivity(s.lot_at(1,1))>Geo.sensitivity(s.lot_at(1,9)),"Residential and industrial sensitivity differ")
	var residential=s.lot_at(1,1).duplicate();residential.kind="house"
	var industrial=s.lot_at(1,9).duplicate();industrial.kind="house"
	expect(Geo.demolition_impact(residential)==10 and Geo.demolition_impact(industrial)==3,"Neighborhood sensitivity changes actual redevelopment approval cost")
	expect(Geo.connection_cost(s.lot_at(0,0))==1050 and Geo.connection_cost(s.lot_at(3,5))==0,"Remote access has a measurable cost")
	s.cash=100000
	s.finance=Sim.Economy.new_finance(s.cash,s.hour)
	var hall=build_at(s,3,5,"datacenter")
	var power=build_at(s,2,5,"power")
	var cooling=build_at(s,3,6,"cooling")
	expect(s.metrics().compute==100,"Original neighboring campus works")
	expect(s.site_preview(hall).power and s.site_preview(hall).cooling,"Preview identifies real connections")
	var far=build_at(s,11,5,"datacenter")
	expect(s.metrics().compute==100 and far in s.metrics().disconnected,"Remote hall remains offline despite spare global capacity")
	s.lots[power].level=3;s.lots[cooling].level=3
	expect(s.metrics().compute==200 and s.metrics().disconnected.is_empty(),"Upgrading utility reach connects remote campus")
	var riverside=build_at(s,7,5,"cooling")
	expect(s.building_stats(s.lots[riverside]).capacity==150,"Riverfront cooling gains 25 percent capacity")
	expect(s.site_preview(riverside,"cooling").river_bonus,"Water access is explained before investment")
	var marker=Sim.cell(7,2)
	var preview=s.site_preview(marker)
	expect(preview.total==4200+1400+4000+4800+350 and preview.hearing==4000,"Protected-site total includes land, access, hearing, demolition and construction")
	s.buy(marker)
	var before=s.cash
	expect(s.demolish(marker)!="" and s.cash==before,"Protected landmark cannot be silently destroyed")
	s.approval=59
	expect(s.redevelopment_permit(marker)!="","Public hearing requires community support")
	s.approval=75
	expect(s.redevelopment_permit(marker)=="" and s.cash==before-4000,"Relocation hearing has a real cost")
	expect(s.demolish(marker)=="" and s.approval==50,"Permit permits redevelopment with stated approval consequence")
	expect(Geo.noise(s.lots,s.lot_at(3,5))>Geo.noise(s.lots,s.lot_at(0,15)),"Noise derives from actual equipment locations")
	# Round trips and genuine 10x10 migrations, including an occupied river parcel.
	s.view_state={"selected":hall,"overlay":"Noise","bookmarks":[{"name":"Campus","zoom":1.4,"pan_x":12.0,"pan_y":-8.0,"selected":hall}]}
	expect(s.save_game(path),"Spatial state saves atomically")
	var restored=Sim.new()
	expect(restored.load_game(path) and restored.lots==s.lots and restored.metrics()==s.metrics(),"Expanded network and permits resume exactly")
	expect(restored.view_state==s.view_state,"Layer and bookmarks persist")
	var original=JSON.parse_string(FileAccess.get_file_as_string(path))
	for version in [1,2,3]:
		var data=original.duplicate(true)
		data.version=version;data.lots=[]
		for y in range(10):
			for x in range(10):
				var lot=Geo.authored_lot(x,y)
				if lot.kind=="water": lot.kind="house";lot.price=1700
				if Vector2i(x,y)==Vector2i(8,5): lot.kind="datacenter";lot.owned=true
				data.lots.append(lot)
		data.view={"selected":58,"zoom":1.4,"pan_x":12,"pan_y":-8}
		write(data)
		expect(restored.load_game(path),"Read genuine version %d 100-parcel town" % version)
		expect(restored.lots.size()==256 and restored.lot_at(8,5).kind=="datacenter" and restored.lot_at(8,5).owned,"Migration preserves buildings on old geography")
		if version==3: expect(restored.view_state.selected==Sim.cell(8,5),"Migration remaps selected parcel by coordinates")
	var data=original.duplicate(true)
	data.view.bookmarks=[{"name":"Invalid","zoom":1,"selected":999,"pan_x":0,"pan_y":0}]
	write(data)
	before=restored.cash
	expect(not restored.load_game(path) and restored.cash==before,"Corrupt camera bookmark cannot replace current town")
	DirAccess.remove_absolute(path)
	var game=load("res://main.tscn").instantiate()
	root.size=Vector2i(1440,900);root.add_child(game)
	await process_frame
	expect(not game.map_tools.visible,"Map panel does not open itself every frame")
	game.focus_lot(hall)
	expect(game.selected==hall and game.town.point(3.5,5.5,10).is_equal_approx(game.town.play_area.get_center()),"Locate centers the cause in the playable area")
	game.map_tools.open();game.map_tools.add_bookmark()
	game.town.center_view();game.map_tools.recall(0)
	expect(game.town.zoom==1.8 and game.selected==hall,"Bookmark restores the actual camera and selection")
	game.map_tools.set_layer("Electricity")
	expect(game.town.overlay=="Electricity" and game.get_view_state().overlay=="Electricity","Map overlay controls the world and save state")
	var route=game.town.walking_route(Vector2i(7,3),Vector2i(10,3))
	expect(not route.is_empty() and route.any(func(v):return floor(v.y)==4),"Residents use a bridge to cross the river")
	for at in route: expect(game.sim.lot_at(floori(at.x),floori(at.y)).kind!="water","Walking route never crosses open water")
	game.queue_free();await process_frame;await create_timer(0.5).timeout
	print("GEOGRAPHY AND MAP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func write(data:Dictionary) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
