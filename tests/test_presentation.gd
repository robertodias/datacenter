extends SceneTree
var checks=0
var failures=0
func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.menu.visible=false
	var sim=game.sim
	var atlas=JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_atlas.json"))
	for family in range(6): expect(atlas.has("family_%d" % family),"Original neighborhood family is packaged: "+str(family))
	for kind in ["datacenter","power","cooling"]:
		for tier in [2,3]: expect(atlas.has("%s_t%d_true" % [kind,tier]) and atlas.has("%s_t%d_false" % [kind,tier]),"Distinct tier art includes online and offline state: "+kind+str(tier))
	var texture=load("res://assets/town_atlas.png");var bitmap=texture.get_image()
	for kind in ["datacenter","power","cooling"]:
		var a=atlas["%s_t2_true" % kind];var b=atlas["%s_t3_true" % kind]
		expect(bitmap.get_region(Rect2i(a[0],a[1],256,256)).get_data()!=bitmap.get_region(Rect2i(b[0],b[1],256,256)).get_data(),"Tier silhouettes are different rendered artwork: "+kind)
	game.soundscape._process(1)
	expect(game.soundscape.current_mood=="small_town","Early company uses calm score")
	sim.completed=["bakery","support"];game.soundscape._process(1)
	expect(game.soundscape.current_mood=="growing_company","Company progress changes score")
	sim.Operations.add_event(sim.ops,"heatwave",sim.hour,10,0);sim.ops.events[0].phase="active";game.soundscape._process(1)
	expect(game.soundscape.current_mood=="under_pressure","Actual incident changes score")
	game.settings.music=false;game.soundscape._process(10)
	expect(game.soundscape.layers.under_pressure.volume_linear<0.001,"Music setting independently mutes adaptive score")
	game.sound_enabled=false;game.soundscape._process(10)
	expect(game.soundscape.layers.values().all(func(p):return p.volume_linear<0.001),"Master mute silences every ambient layer")
	sim.ops.events.clear();sim.completed=["bakery","support","studio","robotics"]
	sim.cash=1000000
	for row in range(3):
		for col in range(3):
			var index=sim.cell(1+col,5+row)
			if sim.lots[index].kind in ["road","water"]: continue
			sim.buy(index)
			if sim.lots[index].kind!="grass": sim.demolish(index)
			sim.build(index,["datacenter","power","cooling"][row])
			for tier in range(col): sim.upgrade(index)
	sim.workforce.jobs.clear();sim.tutorial.enabled=false;sim.notices.clear();sim.take_operation_alerts();sim.take_civic_alerts()
	game.refresh_hud();game.refresh_inspector();game.town.invalidate();game.announced_win=true;game.announced_campaign=true
	game.town.focus(sim.cell(2,6));root.size=Vector2i(1440,900)
	for i in range(45): await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/campus-tiers.png")
		game.menu.open("settings");game.settings.ui_scale=1.15;game.apply_settings(false,false);root.size=Vector2i(1152,720)
		for i in range(30): await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/audio-settings.png")
	game.queue_free();await process_frame
	print("PRESENTATION: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
