extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const R=preload("res://scripts/research.gd")
var Strategy=load(get_script().resource_path.get_base_dir().path_join("operating_strategy.gd"))
var checks=0
var failures=0
var path="user://research-test.json"
func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)
func campus():
	var s=Sim.new();s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	return s
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=campus()
	expect(R.valid(R.fresh()),"Fresh research is valid")
	expect(R.select(s,"predict")!="" and R.select(s,"missing")!="","Prerequisites and unknown projects reject")
	expect(R.allocate(s,11)!="" and s.research.allocation==0,"Only offered allocations accepted")
	expect(R.select(s,"optimize")=="" and R.allocate(s,25)=="","Select a real project and allocation")
	var m=s.metrics()
	expect(m.research_compute==25 and m.spot==75 and m.free==75,"Research reserves physical capacity and reduces spot sales")
	expect(s.accept_contract("bakery")=="" and s.accept_contract("support")!="","Research changes signable capacity")
	s.tick();expect(s.research.progress.optimize==25,"Only delivered compute advances research")
	R.allocate(s,0);s.tick();expect(s.research.progress.optimize==25 and s.metrics().research_compute==0,"Pause releases compute without losing progress")
	s.accept_contract("support");var before=s.metrics();R.allocate(s,50);m=s.metrics()
	expect(before.deliveries.support==60 and m.deliveries.support==10,"Increasing research can starve an already signed customer")
	expect(m.research_compute+m.allocations.bakery+m.allocations.support+m.spot<=m.compute,"Research and customer allocation conserve physical compute")
	R.select(s,"discover");s.tick();expect(s.research.progress.optimize==25 and s.research.progress.discover==50,"Switching retains progress in both branches")
	s.demolish(82);s.tick();expect(s.research.progress.discover==50,"Offline equipment cannot advance research")
	s=campus();R.select(s,"optimize");R.allocate(s,50)
	for i in range(12): s.tick()
	expect(R.has(s,"optimize") and s.research.project=="" and s.metrics().research_compute==0,"Completed research releases capacity automatically")
	expect(is_equal_approx(s.metrics().power_need,56) and s.metrics().cooling_need==36,"Engineer optimization lowers real utility draw")
	expect(s.metrics().compute==100,"Optimization does not invent capacity")
	expect(R.select(s,"optimize")!="" and R.select(s,"predict")=="","Completed projects cannot restart and unlock their successor")
	var minimum=s.cash
	for project in ["predict","discover","outreach","scheduler","water_loop"]:
		R.select(s,project)
		for i in range(180):
			if R.has(s,project): break
			Strategy.tick(s);minimum=minf(minimum,s.cash)
		expect(R.has(s,project),"Paid live campus completes "+project)
	expect(minimum>=0,"All six discoveries are affordable through earned revenue with real incidents")
	expect(R.personality(s)=="Engineer" and s.research.comments.size()>0,"Companion reflects researched specialization and records results")
	expect(is_equal_approx(s.metrics().power_need,58),"Water recovery trades additional cooling electricity for water savings")
	var with_loop=s.metrics().water_use;s.research.completed.erase("water_loop");var without_loop=s.metrics().water_use;s.research.completed.append("water_loop")
	expect(is_equal_approx(with_loop,without_loop*0.65),"Water recovery changes actual measured water demand")
	var lot=s.lots[83];var condition=lot.condition;s.tick();var wear=condition-lot.condition
	s.research.completed.erase("predict");condition=lot.condition;s.tick();var ordinary=condition-lot.condition;s.research.completed.append("predict")
	expect(wear<ordinary,"Predictive maintenance reduces actual condition loss")
	expect(is_equal_approx(s.contract_definition("robotics").penalty_rate,0.16),"Commercial research negotiates lower fees on new critical contracts")
	expect(s.offers().any(func(c):return c.id.begins_with("scout_")) and s.offers().any(func(c):return c.id.begins_with("vision_")),"Research exposes both new customer families")
	var scout=R.offer(s);expect(s.accept_contract(scout.id)=="","Discovered service uses normal signing and reservation")
	expect(not s.offers().any(func(c):return c.id.begins_with("scout_")),"Only one scout customer shown while an introduction is active")
	var cash=s.cash;expect(R.campaign(s,"market")=="" and s.cash==cash-1200,"Adoption campaign charges the ledger")
	expect(R.campaign(s,"market")!="" and s.cash==cash-1200,"Active campaign cannot be charged twice")
	var adoption=s.civic.wards.market.adoption;s.tick();expect(s.civic.wards.market.adoption>adoption,"Invitations grow actual district adoption")
	var shortfalls=s.metrics().local_shortfalls.get("market",0)
	s.demolish(82);expect(s.metrics().local_shortfalls.market>shortfalls,"Unserved campaign demand creates reliability shortfalls")
	s.tick();expect(s.civic.wards.market.service_loss>0,"Failed promises reach civic complaints")
	expect(s.save_game(path),"Research and campaign save succeeds")
	var loaded=Sim.new();expect(loaded.load_game(path),"Version 8 research save loads")
	expect(loaded.research==s.research,"Research progress, timers and companion memory survive reload")
	for i in range(80): s.tick();loaded.tick()
	expect(s.research==loaded.research and s.civic==loaded.civic and s.ops==loaded.ops and s.cash==loaded.cash,"Exact continuation across research/campaign expiry/incidents")
	expect(not R.campaign_active(s,"market"),"Campaign expires on saved simulation clock")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path));data.version=7;data.erase("research")
	write(data);expect(loaded.load_game(path) and loaded.research==R.fresh(),"Version 7 towns migrate with research disabled and no retroactive buffs")
	s.save_game(path);data=JSON.parse_string(FileAccess.get_file_as_string(path));data.research.allocation=99;write(data)
	var old=loaded.cash;expect(not loaded.load_game(path) and loaded.cash==old,"Corrupt research rejects before changing live state")
	var broken=R.fresh();broken.completed=["predict"];broken.progress.predict=1600
	expect(not R.valid(broken),"Corrupt prerequisite chain rejects")
	var preserved=campus();preserved.council("preserve","riverside",39);preserved.tick()
	expect(preserved.research.comments.any(func(c):return c.message.contains("preserved")),"Companion comments on actual preservation")
	var partial=campus();R.select(partial,"scheduler");R.allocate(partial,25)
	for i in range(7): partial.tick()
	partial.save_game(path);var resumed=Sim.new();expect(resumed.load_game(path),"Partially completed research reloads")
	for i in range(100): partial.tick();resumed.tick()
	expect(partial.research==resumed.research and partial.cash==resumed.cash and partial.ops==resumed.ops,"Partial research completes on the same tick after loading")
	var experimental=partial.contract_definition("studio");experimental.progress=0
	partial.hour=24;var boosted=partial.metrics(experimental).speeds.studio
	partial.research.completed.erase("scheduler");var ordinary_speed=partial.metrics(experimental).speeds.studio
	expect(is_equal_approx(boosted,0.9) and is_equal_approx(ordinary_speed,0.65),"Scheduler raises experimental trough without changing physical allocation")
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	s.take_operation_alerts();s.take_civic_alerts();s.notices.clear()
	game.paused=true;game.menu.visible=false;game.sim=s;game.town.sim=s;game.refresh_hud();game.refresh_inspector();game.announced_win=true;game.announced_campaign=true;game.settings.ui_scale=1.15;game.apply_settings(false,false)
	root.size=Vector2i(1152,720);await process_frame;game.layout_stage();game.business.open("research")
	for i in range(4): await process_frame
	expect(game.business.research_view.rows.size()==6 and game.business.research_view.campaigns.size()==5,"Research page exposes every project and district")
	expect(game.business.content_scroll.get_v_scroll_bar().max_value>game.business.content_scroll.size.y,"Long research page scrolls at minimum display and enlarged text")
	game.business.research_view.review_share(50)
	expect(game.dialog.visible and game.dialog.dialog_text.contains("cash flow"),"Allocation review explains economics before applying")
	game.dialog.hide()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/research-minimum.png")
		root.size=Vector2i(1440,900);await process_frame;game.layout_stage()
		game.business.content_scroll.scroll_vertical=10000
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/research-journal.png")
	game.queue_free();await process_frame;await create_timer(0.1).timeout;DirAccess.remove_absolute(path)
	print("RESEARCH: %d checks, %d failures; paid route minimum $%.2f" % [checks,failures,minimum]);quit(1 if failures else 0)
func write(data:Dictionary) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
