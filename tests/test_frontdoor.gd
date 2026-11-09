extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Store=preload("res://scripts/save_store.gd")
const Settings=preload("res://scripts/game_settings.gd")
var checks=0
var failures=0
var store

func expect(condition:bool,message:String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func cleanup() -> void:
	for name in DirAccess.get_files_at(store.directory):
		if name in ["index.cfg","manual_001.json","manual_001.json.bak","manual_001.png","quick.json","quick.json.bak","quick.png","auto_0.json","auto_1.json","auto_2.json","auto_0.json.bak","auto_1.json.bak","auto_2.json.bak","auto_0.png","auto_1.png","auto_2.png","campaign_littlebrook.json","campaign_littlebrook.json.bak","campaign_littlebrook.png"]:
			DirAccess.remove_absolute(store.directory+"/"+name)

func run() -> void:
	root.size=Vector2i(1440,900)
	store=Store.new(true)
	store.directory="user://test_slots"
	store.legacy_path="user://test_slots/nonexistent_legacy.json"
	store.latest_path=""
	DirAccess.make_dir_recursive_absolute(store.directory)
	cleanup()
	var s=Sim.new()
	s.new_game("Test Infrastructure","littlebrook","relaxed")
	expect(s.company_name=="Test Infrastructure" and s.cash==28000,"Company identity and difficulty initialize")
	s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power")
	s.buy(99);s.build(99,"cooling")
	s.accept_contract("bakery")
	for i in range(5):s.tick()
	s.play_seconds=123.4
	var view={"zoom":1.4,"pan_x":71.0,"pan_y":-19.0,"selected":82}
	var image=Image.create(128,72,false,Image.FORMAT_RGB8)
	image.fill(Color("25463c"))
	var path=store.manual_path()
	expect(store.save_slot(s,path,"Before the heat",view,image),"Create named save with image")
	expect(FileAccess.file_exists(path.get_basename()+".png"),"Thumbnail persisted")
	var meta=store.read_metadata(path)
	expect(meta.title=="Before the heat" and meta.company==s.company_name and not meta.damaged,"Save identity and name visible")
	expect(meta.play_seconds==123.4,"Playtime metadata persisted")
	expect(store.manual_path()!=path,"New manual saves never overwrite existing slot")
	var clone=Sim.new()
	expect(store.load_slot(clone,path),"Load named slot")
	expect(clone.active[0].remaining==31 and clone.active[0].progress==200,"Live contract deadline and work persist")
	expect(clone.view_state==view,"Camera and selection restored exactly")
	expect(clone.cash==s.cash and clone.company_name==s.company_name,"Economy and company persist")
	s.tick()
	expect(store.save_slot(s,path,"After an hour",view,image),"Overwrite existing slot")
	expect(FileAccess.file_exists(path+".bak"),"Previous successful save retained")
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var before=clone.cash
	expect(not store.load_slot(clone,path) and clone.cash==before,"Damaged load preserves current town")
	expect(store.read_metadata(path).damaged,"Corrupt save clearly marked")
	expect(store.load_slot(clone,path,true) and clone.active[0].remaining==31,"Recover prior save and its exact contract state")
	for i in range(5):
		s.tick()
		expect(store.autosave(s,view,image),"Rotating autosave succeeds")
	var autos=store.list_saves().filter(func(m):return m.path.get_file().begins_with("auto_"))
	expect(autos.size()==3,"Only three autosave slots rotate")
	expect(store.campaign_save(s,view,image),"Scenario campaign checkpoint saves")
	expect(store.continue_path().ends_with("campaign_littlebrook.json"),"Continue targets last played/saved slot")
	expect(not store.save_slot(s,"user://outside.json","bad",view),"Cannot write outside slot directory")
	expect(store.delete_slot(path),"Delete confirmed slot")
	expect(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"Delete removes its backup too")
	var settings=Settings.new(true)
	settings.path="user://test_settings.cfg"
	settings.ui_scale=1.15
	settings.volume=0.3
	settings.auto_pause=false
	expect(settings.bind_action("pause",KEY_P)=="","Rebind a game control")
	expect(settings.bind_action("buy",KEY_P)!="","Duplicate controls are rejected")
	expect(settings.bind_action("buy",KEY_F11)!="","Display shortcut is protected")
	expect(settings.save_settings(),"Settings save")
	var settings2=Settings.new(true)
	settings2.path=settings.path
	settings2.load_settings()
	expect(is_equal_approx(settings2.ui_scale,1.15) and is_equal_approx(settings2.volume,0.3) and not settings2.auto_pause,"Accessibility and audio settings survive reload")
	expect(settings2.bindings.pause==KEY_P,"Remapped control survives reload")
	DirAccess.remove_absolute(settings.path)
	# Actual menu/new/load navigation, including dirty-state cancellation.
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.saves=store
	game.session_started=false
	game.menu.open("title")
	await process_frame
	expect(game.menu.visible and game.menu.mode=="title","Title screen opens")
	game.menu.open("new")
	await process_frame
	expect(game.menu.company_edit!=null and game.menu.difficulty_choice.selected==1,"Company setup defaults to standard challenge")
	await game.start_company("Another company","littlebrook","standard")
	expect(game.session_started and game.paused and not game.menu.visible,"New town arrives paused after loading")
	expect(FileAccess.file_exists(store.directory+"/campaign_littlebrook.json"),"New company has a scenario checkpoint")
	game.dirty=true
	game.get_window().close_requested.emit()
	expect(game.menu.mode=="unsaved" and game.session_started,"Native window close is routed through the unsaved-work flow")
	game.menu.close()
	game.request_leave(game.return_to_title)
	expect(game.menu.mode=="unsaved","Unsaved changes prompt before leaving")
	game.menu.close()
	expect(game.session_started and game.dirty,"Cancelling leave retains unsaved town")
	game.return_to_title()
	await game.load_town(store.directory+"/campaign_littlebrook.json")
	expect(game.session_started and game.sim.company_name=="Another company" and game.paused,"Continue/load restores named town paused")
	for section in ["settings","credits","save","load"]:
		game.menu.open(section)
		await process_frame
		expect(game.menu.body.position.x>=0 and game.menu.body.position.y>=0,"Menu fits: "+section)
	cleanup()
	print("FRONT DOOR AND SAVES: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
