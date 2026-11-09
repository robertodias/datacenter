extends SceneTree
var Strategy=load(get_script().resource_path.get_base_dir().path_join("operating_strategy.gd"))
const Sim=preload("res://scripts/simulation.gd")
var failures=0
var checks=0

func expect(condition:bool,message:String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",message)

func campus():
	var s=Sim.new()
	s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power")
	s.buy(99);s.build(99,"cooling")
	return s

func wait_for_cash(s,amount:float) -> void:
	var limit=0
	while s.cash<amount and limit<1000:
		Strategy.tick(s)
		limit+=1
	expect(s.cash>=amount,"A working campus can afford its next investment")

func _init() -> void:
	var s=campus()
	expect(s.upgrade(83)!="","Tier 2 starts locked")
	expect(s.accept_contract("atlas")!="","Frontier offer starts locked")
	expect(s.accept_contract("bakery")=="","First project can be signed")
	expect(s.accept_contract("bakery")!="","Duplicate acceptance rejected")
	expect(s.accept_contract("support")=="","Can reserve remaining compute for service")
	expect(s.metrics().free==0 and s.metrics().spot==0,"Reserved compute cannot earn spot revenue twice")
	expect(s.accept_contract("made-up")!="","Unknown offers rejected")
	for i in range(15): Strategy.tick(s)
	expect("bakery" in s.completed and s.active.size()==1,"Project delivers at exact work target")
	expect(s.metrics().spot==40,"Completed project's compute returns to market")
	var path="user://progression-test.json"
	expect(s.save_game(path),"Save mid-service")
	var restored=Sim.new()
	expect(restored.load_game(path),"Reload mid-service")
	expect(restored.active.size()==1 and restored.active[0].remaining==9,"Deadline survives reload")
	expect(restored.active[0].progress==900,"Delivered compute survives reload")
	for i in range(9):
		s.tick()
		restored.tick()
	expect(s.cash==restored.cash and s.completed==restored.completed,"Reloaded contract pays exactly once with same outcome")
	expect(s.campaign_count()==2 and s.tech_level()==2,"Two deliveries unlock GPU technology")
	var cash=s.cash
	s.check_milestones()
	expect(s.cash==cash,"Milestone grant cannot be claimed twice")
	expect(s.upgrade(83)=="","Upgrade first hall using earned funds")
	expect(s.metrics().capacity==220 and s.metrics().power_need==85,"Hall upgrade changes compute and utility demand")
	expect(s.upgrade(82)=="" and s.upgrade(99)=="","Utilities have working tier 2 upgrades")
	expect(s.metrics().cooling==280 and s.metrics().power==260,"Upgraded network supplies campus")
	for id in ["studio","robotics","research","council","atlas","orbital"]:
		var c=s.contract_definition(id)
		if c.compute>s.metrics().compute:
			wait_for_cash(s,22000)
			if s.tech_level()==3:
				if s.lots[82].level<3: expect(s.upgrade(82)=="","Upgrade regional power for frontier loads")
				if s.lots[99].level<3: expect(s.upgrade(99)=="","Upgrade advanced cooling")
				if s.lots[83].level<3: expect(s.upgrade(83)=="","Unlock and build neural supercluster")
			if s.metrics().compute<c.compute:
				var idx=0
				while s.lots[idx].kind!="grass" or s.lots[idx].owned: idx+=1
				expect(s.buy(idx)=="" and s.build(idx,"datacenter")=="","Expand into second hall without injected funds")
				expect(s.upgrade(idx)=="","Second hall GPU upgrade")
		expect(s.accept_contract(id)=="","Accept unlocked customer: "+id)
		var start=s.hour
		while s.active.any(func(a): return a.id==id) and s.hour-start<200: Strategy.tick(s)
		expect(id in s.completed,"Deliver customer: "+id)
		expect(s.cash>=0,"Progression remains solvent after "+id)
	expect(s.campaign_won and s.campaign_count()==8,"Complete the eight-customer campaign")
	expect(s.offers().size()==1 and s.offers()[0].id=="open_0","Repeatable commission appears after campaign")
	expect(s.accept_contract("open_0")=="","Sign repeatable commission")
	expect(s.accept_contract("open_0")!="","Consumed repeatable ticket cannot be replayed")
	while not s.active.is_empty(): Strategy.tick(s)
	expect(s.offers()[0].id=="open_1","Repeatable customers continue indefinitely")
	print("FULL CAMPAIGN: day ",s.hour/24+1," cash $",roundi(s.cash)," capacity ",s.metrics().compute)

	var failed=campus()
	failed.accept_contract("bakery")
	failed.demolish(82)
	for i in range(36): failed.tick()
	expect(failed.active.is_empty() and failed.completed.is_empty(),"Outage can miss a project deadline")
	expect(failed.history[0].outcome=="Deadline missed" and failed.history[0].amount==-220,"Missed project applies stated penalty")
	failed.build(82,"power")
	expect(failed.accept_contract("bakery")=="","Failed customer can be retried")
	expect(failed.cancel_contract("bakery")=="" and failed.active.is_empty(),"Cancellation releases reserved compute")
	expect(failed.metrics().free==100,"Cancelled reservation returns immediately")
	var service=campus()
	service.accept_contract("support")
	service.demolish(82)
	for i in range(3): service.tick()
	service.build(82,"power")
	for i in range(21): service.tick()
	expect("support" in service.completed,"A short interruption is recovered from spare compute")
	service=campus()
	service.accept_contract("support")
	service.demolish(82)
	for i in range(8): service.tick()
	service.build(82,"power")
	for i in range(16): service.tick()
	expect(service.completed.is_empty(),"Service below 90 percent after catch-up forfeits completion bonus")
	expect(service.earned>0,"Partially delivered services still earn delivered hourly revenue")
	var civic=campus()
	var approval=civic.approval
	expect(civic.invest_community()=="" and civic.approval==approval+10,"Community grant restores approval")
	expect(civic.invest_community()!="","Community grant has a real cooldown")
	var greenfield=Sim.new()
	for pair in [[115,"datacenter"],[82,"power"],[99,"cooling"]]:
		greenfield.buy(pair[0])
		if greenfield.lots[pair[0]].kind!="grass": greenfield.lots[pair[0]].kind="grass"
		greenfield.build(pair[0],pair[1])
	for i in range(10): greenfield.tick()
	expect(greenfield.won and not greenfield.cleared,"A campus on empty land can advance without unnecessary demolition")

	# Old saves migrate; invalid new saves never partially mutate the live company.
	s.save_game(path)
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	data.version=1
	for lot in data.lots: lot.erase("level")
	write_json(path,data)
	var legacy=Sim.new()
	expect(legacy.load_game(path) and legacy.lots[83].level==1,"Version 1 towns load with starter equipment")
	expect(legacy.completed.is_empty() and legacy.active.is_empty(),"Migration starts a clean customer portfolio")
	s.save_game(path)
	data=JSON.parse_string(FileAccess.get_file_as_string(path))
	data.active=[{"id":"bad"}]
	write_json(path,data)
	var old_cash=s.cash
	expect(not s.load_game(path) and s.cash==old_cash,"Malformed contracts cannot overwrite the live town")
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path+".v0-backup"): DirAccess.remove_absolute(path+".v0-backup")
	print("PROGRESSION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func write_json(path:String,data:Dictionary) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
