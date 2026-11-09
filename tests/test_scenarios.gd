extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var Strategy=load(get_script().resource_path.get_base_dir().path_join("operating_strategy.gd"))
var checks=0
var failures=0
var path="user://scenario-test.json"
func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)
func campus(town:String):
	var s=Sim.new();s.new_game("Scenario QA",town)
	s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling");return s
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var little=campus("littlebrook");var sun=campus("sunsprawl");var old=campus("oldbridge")
	expect(little.lots!=sun.lots and old.lots!=little.lots,"Each town has authored parcel differences")
	expect(sun.lots.all(func(lot):return lot.kind!="water"),"Dry Sunsprawl removes the river corridor")
	expect(not sun.Geography.river_access(sun.lots[87]),"Sunsprawl cannot claim a nonexistent river cooling bonus")
	expect(old.lots.filter(func(lot):return lot.kind=="monument").size()==6,"Oldbridge contains six protected heritage landmarks")
	expect(old.lots[0].price>little.lots[0].price,"Historic land carries a redevelopment premium")
	expect(is_equal_approx(sun.metrics().cooling,102) and sun.metrics().power==108 and sun.metrics().cooling_need==44,"Sunsprawl climate changes actual utility supply and demand")
	expect(little.metrics().cooling==120 and little.metrics().cooling_need==40,"Littlebrook retains its established climate")
	old.completed=["bakery","support","studio","robotics","research","council","atlas","orbital"];old.check_milestones()
	expect(not old.campaign_won,"Oldbridge cannot win from customers alone")
	for index in [17,35,102]: expect(old.council("preserve",old.lots[index].district,index)=="","Preservation is a paid physical civic action")
	old.check_milestones();expect(old.campaign_won and old.scenario_progress.distinctions.size()>0,"Oldbridge finale recognizes preservation, approval and rehousing")
	old.approval=1;old.check_milestones();expect(old.campaign_won,"Earned finale remains completed after later sandbox choices")
	for town in ["sunsprawl","oldbridge"]: play(town)
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.paused=true;game.settings.ui_scale=1.15;game.apply_settings(false,false)
	game.menu.open("new");await process_frame
	expect(game.menu.scenario_choice.item_count==4,"New company offers three towns plus sandbox")
	game.menu.scenario_choice.select(2);game.menu.scenario_choice.item_selected.emit(2)
	expect(game.menu.body.find_children("*","Label",true,false).any(func(l):return l.text.contains("no river cooling")),"Scenario selection updates the actual town brief")
	game.menu.visible=false;game.sim=sun;game.town.sim=sun;game.refresh_hud();game.refresh_inspector()
	game.business.open("scenario");root.size=Vector2i(1152,720)
	for i in range(30): await process_frame
	expect(game.business.scenario_view!=null and game.business.scenario_view.next_button.disabled,"Town charter explains goals and gates the next-town action")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/scenario-charter.png")
		game.business.visible=false;root.size=Vector2i(1440,900);await process_frame;game.layout_stage();game.town.center_view()
		for i in range(30): await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/sunsprawl.png")
		game.sim=campus("oldbridge");game.town.sim=game.sim;game.refresh_hud();game.town.invalidate()
		for i in range(30): await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/oldbridge.png")
	game.queue_free();await process_frame;await create_timer(0.1).timeout;DirAccess.remove_absolute(path)
	print("SCENARIOS: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
func play(town:String) -> void:
	var s=campus(town);var minimum=s.cash
	for id in ["bakery","support","studio","robotics","research","council","atlas","orbital"]:
		var c=s.contract_definition(id);var waits=0
		while s.metrics().compute<c.compute and waits<1500:
			for site in [83,82,99]:
				var lot:Dictionary=s.lots[site]
				if s.tech_level()>lot.level and s.cash>=s.TIERS[lot.kind][lot.level].cost: s.upgrade(site)
			if s.lots[83].level==3 and s.metrics().compute<c.compute:
				if s.lots[115].kind=="grass" and s.cash>=s.lots[115].price+s.construction_cost(115,"datacenter"): s.buy(115);s.build(115,"datacenter")
				if s.lots[115].kind=="datacenter" and s.lots[115].level<2 and s.cash>=5200: s.upgrade(115)
			if s.metrics().compute>=c.compute: break
			Strategy.tick(s);minimum=minf(minimum,s.cash);waits+=1
		expect(s.accept_contract(id)=="",town+" signs "+id+" with earned cash")
		for i in range(100):
			if not s.active.any(func(c):return c.id==id): break
			Strategy.tick(s);minimum=minf(minimum,s.cash)
		expect(id in s.completed,town+" delivers "+id)
	if town=="oldbridge":
		for site in [17,35,102]: s.council("preserve",s.lots[site].district,site)
		if s.approval<65: s.invest_community()
	for i in range(120):
		if s.campaign_won: break
		Strategy.tick(s);minimum=minf(minimum,s.cash)
	if s.finance.debt>0: s.repay(s.finance.debt)
	expect(s.campaign_won and minimum>=0,town+" reaches its actual finale solvent")
	expect(absf(s.finance.opening_cash+s.Economy.total(s.finance.totals)-s.cash)<0.02,town+" ledger reconciles")
	expect(s.save_game(path),town+" saves its authored town and objective state")
	var loaded=Sim.new();expect(loaded.load_game(path),town+" reloads")
	for i in range(50): s.tick();loaded.tick()
	expect(s.lots==loaded.lots and s.cash==loaded.cash and s.scenario_progress==loaded.scenario_progress and s.ops==loaded.ops,town+" exact continuation preserves climate, objectives and geography")
	print("TOWN ",town,": minimum $",minimum,"; final $",s.cash,"; complete ",s.campaign_won,"; sustainable ",s.scenario_progress.best_sustainable)
