extends SceneTree
## Regression checks for the November 2026 code review: simulation fixes and the
## click-to-act map tools. Isolated QA saves only.
const Sim=preload("res://scripts/simulation.gd")
const Ops=preload("res://scripts/operations.gd")
const Work=preload("res://scripts/workforce.gd")
var checks=0
var failures=0

func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)

func campus():
	var s=Sim.new()
	s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	return s

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# Offline equipment draws no power or cooling.
	var s=campus()
	var before=s.metrics()
	s.lots[83].failed=true
	var after=s.metrics()
	expect(before.power_need>after.power_need and after.cooling_need<before.cooling_need,"Failed hall stops drawing power and cooling")
	expect(is_equal_approx(after.power_need,20) and after.compute==0,"Only the cooling plant's own draw remains")
	# Upgrades are blocked while a building is failed.
	s.completed=["bakery","support"];s.cash=50000
	expect(s.upgrade(83)!="","Failed hall cannot be upgraded")
	s.lots[83].failed=false
	expect(s.upgrade(83)=="","Repaired hall can be upgraded")
	# Mobile cooling stops when its staging site is cleared; the rental moves with the campus.
	s=campus();s.cash=50000
	expect(s.operate("rental",83)=="","Rental staged at the hall")
	s.demolish(99)
	expect(s.metrics().cooling>0,"Rental still cools while its staging hall stands")
	s.demolish(83)
	expect(s.ops.rental_site!=83 and (s.ops.rental_site<0 or Sim.BUILDINGS.has(s.lots[s.ops.rental_site].kind)),"Rental site moves off a demolished building")
	# Renewal extends rather than discarding paid hours.
	s=campus();s.cash=50000
	s.operate("rental",83)
	for i in range(21): s.tick()
	var end=s.ops.rental_until
	expect(s.operate("rental",83)=="" and s.ops.rental_until==end+24,"Renewal adds 24h to the current rental")
	# Backup gear follows a demolished hub, and modules cannot be bought for a missing hub.
	s=campus();s.cash=50000
	s.operate("battery",82)
	s.buy(98);s.demolish(98);s.build(98,"power")
	s.demolish(82)
	expect(s.ops.hub==98,"Backup hub moves to the remaining substation")
	s.demolish(98)
	expect(s.ops.hub==-1,"Hub clears when no substation remains")
	expect(s.operate("battery")!="","Battery cannot be bought without a substation")
	# Warm standby with an empty tank switches off instead of billing.
	s=campus();s.cash=50000
	s.operate("generator",82);s.operate("fuel");s.operate("warm")
	s.ops.fuel=0.0
	s.tick()
	expect(not s.ops.warm,"Warm standby stops when the tank is empty")
	expect(s.metrics().operations==0,"No standby charge without fuel")
	# Broken promises keep stress inside the save validator's range.
	s=campus()
	var w=s.civic.wards.oldtown
	w.stress=60.0;w.ceasefire_until=s.hour+1;w.promise_cause="noise";w.promise_value=-1.0
	s.civic.grace_until=0
	s.tick()
	expect(w.stress<=60,"Broken promise cannot push stress past 60")
	# Expedited permits need an actual permit pause.
	s=campus();s.cash=50000
	expect(s.council("expedite","oldtown")!="","Expedite refused without a permit pause")
	# Staff recruitment has an up-front fee.
	s=campus();s.cash=1000
	var cash=s.cash
	expect(Work.set_team(s,"commercial",1)=="" and is_equal_approx(s.cash,cash-72),"Recruiting a commercial team costs 12h of wages")
	expect(Work.set_team(s,"commercial",0)=="" and is_equal_approx(s.cash,cash-72),"Dismissing a team is free")
	s.cash=10
	expect(Work.set_team(s,"engineers",1)!="","Recruiting requires cash")
	# Preventive auto-service waits during incidents; failures are still repaired.
	s=campus();s.cash=50000
	Work.set_team(s,"technicians",1)
	Ops.add_event(s.ops,"heatwave",s.hour+20,6,12)
	for i in range(10): s.tick()
	s.lots[82].condition=40.0
	s.tick()
	expect(int(s.lots[82].get("service_until",0))<=s.hour,"No preventive visit while a heatwave is forecast")
	s.lots[99].failed=true
	s.tick()
	expect(int(s.lots[99].get("service_until",0))>s.hour,"Failed equipment is still repaired during a forecast")
	# Routine alerts are tagged so they do not auto-pause the game.
	expect(s.ops.alerts.any(func(a):return a.get("routine",false)) or s.take_operation_alerts().any(func(a):return a.get("routine",false)),"Technician dispatch is a routine alert")
	# Save summary counts campaign deliveries only.
	s=campus()
	s.completed=["bakery","scout_0","open_1"]
	expect(s.campaign_count()==1,"Campaign count ignores scout/open commissions")
	# Map tools act on click.
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.paused=true;game.sim.new_game();game.sim.cash=50000
	var plot=game.sim.cell(5,7)
	game.set_tool("buy");game.on_selected(plot);game.apply_tool(plot)
	expect(game.sim.lots[plot].owned,"Buy tool buys the clicked plot")
	game.set_tool("datacenter")
	var tag=game.tool_tag(plot)
	expect(tag.text.begins_with("Build") and tag.tone in ["ok","warn"],"Cursor tag quotes the build price")
	game.apply_tool(plot)
	expect(game.sim.lots[plot].kind=="datacenter","Hall tool builds on an owned cleared plot")
	expect(game.tool_tag(game.sim.cell(0,4)).tone=="bad" or game.sim.lots[game.sim.cell(0,4)].kind not in ["road","water"],"Public land is refused")
	game.set_tool("inspect");game.apply_tool(game.sim.cell(6,7))
	expect(not game.sim.lots[game.sim.cell(6,7)].owned,"Inspect never buys")
	game.inspector_open=false;game.inspector.visible=false
	game.on_selected(plot)
	expect(game.inspector.visible,"Selecting a plot reopens a closed inspector")
	game.queue_free();await process_frame
	print("REVIEW FIXES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
