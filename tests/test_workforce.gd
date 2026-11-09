extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Work=preload("res://scripts/workforce.gd")
var checks=0
var failures=0
var path="user://workforce-test.json"
func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)
func campus():
	var s=Sim.new();s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling");return s
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=campus();var base=s.metrics().staff
	expect(Work.valid(s.workforce) and s.workforce.jobs.size()==3,"Each real construction creates a saved delivery")
	expect(Work.set_team(s,"technicians",4)!="" and Work.set_team(s,"unknown",1)!="","Invalid teams cannot be hired")
	Work.set_team(s,"technicians",1);Work.set_team(s,"engineers",2);Work.set_team(s,"commercial",1)
	expect(Work.wages(s)==31 and s.metrics().staff==base+31,"Specialist wages enter operating costs")
	var cash=s.cash;var forecast=s.metrics().profit;s.tick()
	expect(is_equal_approx(s.cash,cash+forecast),"The hourly ledger actually pays specialist wages")
	var project=s.contract_definition("bakery")
	expect(project.deadline==40 and is_equal_approx(project.penalty_rate,0.09),"Commercial staff negotiate new project time and fees")
	s.accept_contract("bakery");Work.set_team(s,"commercial",3)
	expect(s.active[0].deadline==40 and s.contract_definition("studio").deadline==60,"Existing customer terms stay fixed after hiring")
	expect(s.contract_definition("support").deadline==24 and s.contract_definition("support").work==1440,"Commercial staff never extend service time without pay")
	s.lots[83].condition=20;s.lots[83].failed=true;s.lots[82].condition=20;s.lots[82].failed=true
	s.workforce.priority="Utilities first";var before=s.cash;s.tick()
	expect(s.lots[82].service_until==s.hour+2 and s.lots[83].service_until==0,"One technician prioritizes utility repair; engineers reduce four hours to two")
	expect(s.workforce.jobs.any(func(j):return j.site==82 and j.kind=="repair"),"Actual automated repair creates a visit at its equipment")
	Work.set_team(s,"engineers",0)
	expect(s.lots[82].service_until==s.hour+2,"Reducing engineering leaves paid visit timing unchanged")
	Work.set_team(s,"technicians",2);s.tick()
	expect(s.lots[83].service_until==s.hour+4,"A second technician dispatches a concurrent repair")
	var visits=s.workforce.jobs.filter(func(j):return j.kind=="repair").size();s.tick()
	expect(s.workforce.jobs.filter(func(j):return j.kind=="repair").size()<=visits,"Ongoing work is never charged or dispatched twice")
	expect(not s.lots[82].failed and s.lots[82].condition>99,"Completed utility visit restores actual equipment")
	Work.set_team(s,"engineers",3)
	expect(Work.duration(s,4)==1 and Work.duration(s,2)==1,"Engineering never reduces work below one simulation hour")
	for i in range(4): s.tick()
	expect(not s.lots[83].failed and s.workforce.history.any(func(j):return j.site==83 and j.kind=="repair"),"Completed work enters dispatch history")
	expect(s.refit(83,"efficient")=="" and s.lots[83].refit_until==s.hour+1,"Engineers shorten a real paid hardware refit")
	expect(s.workforce.jobs.any(func(j):return j.kind=="refit"),"Refit delivery mirrors equipment downtime")
	expect(s.save_game(path),"Workforce saves while work is underway")
	var loaded=Sim.new();expect(loaded.load_game(path) and loaded.workforce==s.workforce,"Roles, priority, dispatches and history round-trip")
	for i in range(60): s.tick();loaded.tick()
	expect(s.cash==loaded.cash and s.workforce==loaded.workforce and s.lots==loaded.lots and s.ops==loaded.ops,"Exact continuation of work, wages and incident state")
	var poor=campus();poor.cash=0;Work.set_team(poor,"technicians",1);poor.lots[83].failed=true;poor.lots[83].condition=0
	Work.advance(poor)
	expect(poor.cash==0 and poor.lots[83].service_until==0,"Unaffordable automatic visits wait instead of silently borrowing")
	var manual=campus();manual.lots[83].condition=80;expect(manual.operate("service",83)=="","Outside manual service remains available without hired staff")
	var cleared=campus();cleared.demolish(83)
	expect(not cleared.workforce.jobs.any(func(j):return j.site==83),"Clearing a site removes stale delivery jobs")
	var corrupt=s.workforce.duplicate(true);corrupt.technicians=-1
	expect(not Work.valid(corrupt),"Corrupt negative teams reject")
	s.save_game(path);var data=JSON.parse_string(FileAccess.get_file_as_string(path));data.version=8;data.erase("workforce")
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	expect(loaded.load_game(path) and loaded.workforce==Work.fresh(),"Version 8 saves migrate with no surprise wages")
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.menu.visible=false
	game.settings.ui_scale=1.15;game.apply_settings(false,false)
	game.sim=manual;game.town.sim=manual;manual.take_operation_alerts();manual.take_civic_alerts();manual.notices.clear()
	game.refresh_hud();game.refresh_inspector();root.size=Vector2i(1152,720)
	await process_frame;game.layout_stage();game.business.open("workforce")
	for i in range(4): await process_frame
	expect(game.business.workforce_view.team_rows.size()==12,"Staff page exposes all role levels")
	expect(game.business.content_scroll.get_v_scroll_bar().max_value>442,"Enlarged staff page is scrollable at minimum resolution")
	var person=game.town.pedestrians[0];manual.hour=1
	expect(game.town.resident_destination(person).purpose=="Heading home","Citizens have a night destination")
	manual.hour=10;expect(game.town.resident_destination(person).purpose.contains("work"),"Day routine selects employment destination")
	manual.hour=18;expect(game.town.resident_destination(person).purpose.contains("park"),"Evening routine visits an actual park")
	var destination=game.town.resident_destination(person)
	var target=manual.lots[destination.site];var route=game.town.walking_route(Vector2i(3,5),Vector2i(target.x,target.y))
	expect(route.all(func(pos):return manual.lot_at(int(pos.x),int(pos.y)).kind!="water"),"Destination routes use bridges instead of crossing water")
	manual.hour=8;game.town.work_fraction=0.8
	var job=manual.workforce.jobs[0];var position=game.town.dispatch_position(job)
	expect(position.x>=0 and position.y>=0 and position.x<=16 and position.y<=16,"A saved dispatch has a bounded world position")
	game.town.activity_speed=0;var prior=person.pos;game.town._process(1)
	expect(person.pos==prior,"Pause and reduced motion freeze pedestrian animation")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/workforce-minimum.png")
		game.business.visible=false;root.size=Vector2i(1440,900);await process_frame;game.layout_stage();game.town.focus(83)
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/workforce-dispatch.png")
	game.queue_free();await process_frame;await create_timer(0.1).timeout;DirAccess.remove_absolute(path)
	print("WORKFORCE: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
