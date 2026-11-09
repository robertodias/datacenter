extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.paused=true;game.settings.auto_pause=false;game.menu.visible=false
	var s=game.sim;s.new_game("Large-campus performance fixture","sandbox")
	s.post("grant",10000000,"QA performance capital");s.completed=["bakery","support","studio","robotics"]
	var built=0
	for i in range(s.lots.size()):
		if s.lots[i].kind!="grass" or built>=60: continue
		var kind=["power","cooling","datacenter"][built%3]
		s.buy(i);s.build(i,kind);s.upgrade(i);s.upgrade(i);built+=1
	s.Workforce.set_team(s,"technicians",3);s.Workforce.set_team(s,"engineers",2)
	s.notices.clear();s.take_operation_alerts();s.take_civic_alerts()
	game.notice_queue.clear();game.announced_win=true;game.announced_campaign=true
	game.refresh_hud();game.refresh_inspector();game.town.center_view();game.town.invalidate()
	game.speed=6;game.paused=false
	await create_timer(2).timeout
	var samples=[];var draws=[]
	for i in range(12):
		await create_timer(1).timeout
		samples.append(Engine.get_frames_per_second());draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var report={"buildings":built,"resolution":[1920,1080],"speed":6,"fps_samples":samples,"minimum_fps":samples.min(),"average_fps":samples.reduce(func(a,b):return a+b,0.0)/samples.size(),"max_draw_calls":draws.max(),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"notes":"Funded QA stress fixture; current machine only, with another preview still open. Not a minimum-spec guarantee."}
	var f=FileAccess.open("C:/Users/Usuario/Development/datacenter/build/performance-1.2.0.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/dense-campus.png")
	game.queue_free();await process_frame;await create_timer(0.1).timeout
	print("LARGE CAMPUS: ",JSON.stringify(report));quit(0 if built==60 else 1)
