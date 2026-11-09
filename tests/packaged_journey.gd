extends SceneTree
## Run against the exported EXE, not from its editor project.
var checks=0
var failures=0

func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	expect(game.menu.visible and game.menu.mode=="title","Exported game opens at title")
	expect(game.sim.lots.size()==256,"Packaged geography is current")
	game.saves.directory="user://packaged_test_slots"
	game.saves.latest_path=""
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	await game.start_company("Packaged Littlebrook QA","littlebrook","standard")
	expect(game.paused and game.session_started,"Company arrives paused after real loading")
	for operation in [[83,"datacenter"],[82,"power"],[99,"cooling"]]:
		expect(game.sim.buy(operation[0])=="","Buy campus property")
		if game.sim.lots[operation[0]].kind!="grass": expect(game.sim.demolish(operation[0])=="","Clear warehouse")
		expect(game.sim.build(operation[0],operation[1])=="","Construct campus equipment")
	expect(game.sim.metrics().compute==100,"Packaged campus supplies online compute")
	expect(game.sim.accept_contract("bakery")=="","Sign customer from actual capacity")
	for i in range(3): game.sim.tick()
	game.refresh_hud();game.refresh_inspector();game.town.invalidate()
	game.focus_lot(83)
	game.map_tools.open();game.map_tools.add_bookmark();game.map_tools.set_layer("Electricity")
	game.map_tools.visible=false
	await process_frame;await RenderingServer.frame_post_draw
	game.capture_thumbnail()
	var path=game.saves.directory+"/manual_packaged.json"
	expect(game.save_to(path,"Packaged campus"),"Named slot writes from compiled release")
	expect(FileAccess.file_exists(path),"Named town file exists")
	expect(FileAccess.file_exists(path.get_basename()+".png"),"Packaged save has a screenshot")
	game.return_to_title()
	expect(game.menu.mode=="title" and not game.session_started,"Leave town for title")
	game.sim.new_game("Wrong company","sandbox","relaxed")
	await game.load_town(path)
	expect(game.paused and game.sim.company_name=="Packaged Littlebrook QA","Company restores paused")
	expect(game.sim.active.size()==1 and game.sim.active[0].progress==120,"Exact customer work resumes")
	expect(game.map_tools.bookmarks.size()==1 and game.map_tools.layer=="Electricity","Camera bookmarks and layer resume")
	expect(game.sim.metrics().compute==100,"Loaded release campus still operates")
	expect(game.sim.borrow()=="" and game.sim.refit(83,"efficient")=="","Release can finance a hardware refit")
	expect(game.save_to(path,"Mid-refit with loan"),"Release saves its hardware and finance state")
	game.sim.tick();game.sim.tick();game.sim.repay()
	await game.load_town(path)
	expect(game.sim.finance.debt==5000 and game.sim.metrics().compute==0,"Reload restores principal and exact refit downtime")
	game.sim.tick();game.sim.tick()
	expect(game.sim.lots[83].hardware=="efficient" and game.sim.metrics().power_need==46,"Restored refit completes with the correct power demand")
	game.refresh_hud();game.refresh_inspector()
	game.settings.ui_scale=1.15;game.apply_settings(false,false)
	game.business.open("hardware")
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/packaged-economy.png")==OK,"Packaged hardware report renders at enlarged text size")
	expect(game.sim.operate("battery")=="" and game.sim.operate("generator")=="" and game.sim.operate("fuel")=="" and game.sim.operate("rental")=="","Exported game can purchase real resilience equipment")
	game.sim.Operations.add_event(game.sim.ops,"outage",game.sim.hour+1,5,0)
	game.sim.Operations.add_event(game.sim.ops,"heatwave",game.sim.hour+1,7,0)
	game.sim.tick();game.handle_operation_alerts();game.refresh_hud();game.refresh_inspector()
	var incident_state=game.sim.ops.duplicate(true)
	expect(game.save_to(path,"Combined live incidents"),"Export saves combined incidents with charged reserves")
	for i in range(3): game.sim.tick()
	await game.load_town(path)
	expect(game.sim.ops==incident_state and game.sim.metrics().weather.grid==0,"Export restores incident phases, random state, battery charge and fuel exactly")
	game.sim.tick();game.sim.tick()
	expect(game.sim.metrics().compute==100 and game.sim.ops.fuel<12,"Restored generator takes over and protects actual compute")
	game.refresh_hud();game.refresh_inspector();game.business.open("operations")
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/packaged-operations.png")==OK,"Export renders live operations with enlarged text")
	game.map_tools.open()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/packaged-atlas.png")==OK,"Release UI renders to inspection artifact")
	game.map_tools.visible=false
	game.sim.borrow(10000)
	var homes=[]
	for i in range(game.sim.lots.size()):
		if game.sim.lots[i].kind=="house" and game.sim.Civic.ward_for(game.sim.lots[i])=="oldtown": homes.append(i)
	for i in range(3): game.sim.buy(homes[i]);game.sim.demolish(homes[i])
	for i in range(36): game.sim.tick()
	expect(game.sim.civic.wards.oldtown.stage==4,"Exported campaign reaches a real displacement permit pause")
	expect(game.sim.council("negotiate","oldtown")=="","Exported game makes a measurable paid council promise")
	game.handle_operation_alerts();game.paused=true;game.open_town("oldtown")
	var citizen_state=game.sim.civic.duplicate(true)
	expect(game.save_to(path,"Council agreement and protests"),"Release saves civic timers and history")
	game.sim.tick();await game.load_town(path)
	expect(game.sim.civic==citizen_state,"Release reload restores an active civic agreement exactly")
	game.open_town("oldtown")
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/packaged-council.png")==OK,"Release renders council demands at enlarged text")
	for i in range(3):
		var site=game.sim.Civic.project_site(game.sim,"oldtown",-1)
		expect(game.sim.council("housing","oldtown",site)=="","Release pays for actual rehousing")
	game.sim.invest_community()
	for i in range(28): game.sim.tick()
	expect(game.sim.civic.wards.oldtown.stage==0,"Restored release agreement can recover from the protest")
	expect(ProjectSettings.get_setting("application/config/name")=="Hyperscale: Datacenter Tycoon","Packaged game has the requested new title")
	print("PACKAGED WINDOWS JOURNEY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
