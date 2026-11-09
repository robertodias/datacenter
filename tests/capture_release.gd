extends SceneTree
## Actual game renderer and paid simulation actions; isolated QA saves only.
const Sim=preload("res://scripts/simulation.gd")
var Strategy=load(get_script().resource_path.get_base_dir().path_join("operating_strategy.gd"))
var game
var folder="C:/Users/Usuario/Development/datacenter/release/steam/screenshots/"
var filming=false
func _initialize() -> void: call_deferred("run")
func hold(seconds:float=1.0) -> void:
	if not filming:
		await create_timer(1.3).timeout
	else:
		for i in range(roundi(seconds*30)): await process_frame
func shot(name:String) -> void:
	game.update_time_controls()
	game.refresh_hud()
	await hold()
	await RenderingServer.frame_post_draw
	var bitmap=root.get_texture().get_image()
	if bitmap.get_size()!=Vector2i(1920,1080) or bitmap.save_png(folder+name+".png")!=OK:
		printerr("Capture failed: ",name," size ",bitmap.get_size()," root ",root.size);quit(1)
func setup(town:String) -> void:
	await game.start_company("Horizon Infrastructure",town,"standard",false)
	var s=game.sim
	s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	s.accept_contract("bakery");s.accept_contract("support")
	refresh()
func refresh() -> void:
	game.sim.notices.clear();game.sim.take_operation_alerts();game.sim.take_civic_alerts()
	game.notice_queue.clear();game.announced_win=true;game.announced_campaign=true
	game.toast_timer=0;game.business.visible=false;game.menu.visible=false;game.dialog.hide()
	game.refresh_hud();game.refresh_inspector();game.town.reset_residents();game.town.invalidate()
func progress() -> void:
	var s=game.sim
	for i in range(26): Strategy.tick(s)
	for id in ["studio","robotics","research","council"]:
		var c=s.contract_definition(id)
		for wait in range(1500):
			for site in [83,82,99]:
				var lot=s.lots[site]
				if s.tech_level()>lot.level and s.cash>=s.TIERS[lot.kind][lot.level].cost: s.upgrade(site)
			if s.metrics().compute>=c.compute: break
			Strategy.tick(s)
		if s.accept_contract(id)!="": printerr("Capture route could not sign ",id);quit(1);return
		for i in range(100):
			if id in s.completed: break
			Strategy.tick(s)
	s.buy(115);s.build(115,"datacenter");s.upgrade(115)
	s.Workforce.set_team(s,"technicians",1);s.Workforce.set_team(s,"engineers",1)
	s.Research.select(s,"optimize");s.Research.allocate(s,25)
	for i in range(8): Strategy.tick(s)
	s.Research.select(s,"predict");s.Research.allocate(s,10)
	s.accept_contract("atlas")
	refresh()
func run() -> void:
	filming="--film" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.paused=true;game.settings.music=true;game.settings.ambience=true
	game.settings.auto_pause=false
	await setup("littlebrook")
	game.on_selected(83);game.town.focus(83);game.paused=false;game.refresh_hud()
	await shot("01-first-campus");await hold(6)
	game.business.open("offers");await shot("02-company-contracts");await hold(5)
	game.business.visible=false;game.paused=true;progress();game.town.focus(83)
	game.paused=false;await shot("03-growing-campus");await hold(9)
	game.business.open("research");await shot("04-research-and-progression");await hold(5)
	game.business.visible=false;game.paused=true
	await setup("sunsprawl");game.town.center_view();game.paused=false
	await shot("05-sunsprawl");await hold(7)
	game.paused=true;await setup("oldbridge");game.town.center_view();game.paused=false
	await shot("06-oldbridge");await hold(7)
	game.business.open("clients");game.business.client_filter="FreeAGI";game.business.refresh()
	await shot("07-fictional-companies");await hold(4)
	game.queue_free();await process_frame;await create_timer(0.1).timeout
	print("RELEASE CAPTURE: seven actual 1920x1080 game screenshots; paid campaign fixture; isolated QA saves")
	quit()
